`timescale 1ns/1ps
`default_nettype none

// Testbench simples para variar o PR do EF_TMR32_WB.
//
// Objetivo:
//   Verificar se o prescaler PR altera a velocidade do timer.
//
// Regra esperada:
//   O timer muda de valor a cada (PR + 1) clocks.
//
// Exemplos:
//   PR = 0  -> TMR muda a cada 1 clock
//   PR = 1  -> TMR muda a cada 2 clocks
//   PR = 4  -> TMR muda a cada 5 clocks
//
// Este TB:
//   1) escreve PR via Wishbone;
//   2) mede o intervalo entre mudancas de TMR;
//   3) testa UP, DOWN e UP/DOWN com PR variado;
//   4) testa interrupcoes CMPX, CMPY e limite com PR variado.
//
// Observacao:
//   A configuracao e feita via Wishbone.
//   A medicao exata do intervalo usa o sinal interno do DUT:
//     dut.instance_to_wrap.tmr
//   Isso deixa o teste mais simples e evita perder valores quando PR e pequeno.

module tb_timer_wb_pr_variado_simples;

  reg clk_i = 1'b0;
  reg rst_i = 1'b1;

  reg  [31:0] adr_i = 32'd0;
  reg  [31:0] dat_i = 32'd0;
  wire [31:0] dat_o;

  reg  [3:0] sel_i = 4'hF;
  reg        cyc_i = 1'b0;
  reg        stb_i = 1'b0;
  reg        we_i  = 1'b0;
  wire       ack_o;

  wire IRQ;
  wire pwm0;
  wire pwm1;
  reg  pwm_fault = 1'b0;

  localparam TMR    = 32'h0000_0000;
  localparam RELOAD = 32'h0000_0004;
  localparam PR     = 32'h0000_0008;
  localparam CMPX   = 32'h0000_000C;
  localparam CMPY   = 32'h0000_0010;
  localparam CTRL   = 32'h0000_0014;
  localparam CFG    = 32'h0000_0018;
  localparam IM     = 32'h0000_FF00;
  localparam RIS    = 32'h0000_FF08;
  localparam IC     = 32'h0000_FF0C;
  localparam GCLK   = 32'h0000_FF10;

  localparam CFG_PERIODIC_DOWN = 32'h5; // 3'b1_01
  localparam CFG_PERIODIC_UP   = 32'h6; // 3'b1_10
  localparam CFG_PERIODIC_UD   = 32'h7; // 3'b1_11

  localparam IRQ_TO = 3'b001;
  localparam IRQ_MX = 3'b010;
  localparam IRQ_MY = 3'b100;

  integer erros = 0;
  integer ciclos_medidos;
  integer pr_random;
  integer i;

  reg [31:0] valor_lido;
  reg [31:0] ris_lido;
  reg [31:0] tmr_antigo;

  EF_TMR32_WB dut (
    .clk_i(clk_i),
    .rst_i(rst_i),
    .adr_i(adr_i),
    .dat_i(dat_i),
    .dat_o(dat_o),
    .sel_i(sel_i),
    .cyc_i(cyc_i),
    .stb_i(stb_i),
    .ack_o(ack_o),
    .we_i(we_i),
    .IRQ(IRQ),
    .pwm0(pwm0),
    .pwm1(pwm1),
    .pwm_fault(pwm_fault)
  );

  always #5 clk_i = ~clk_i;

  task wb_write;
    input [31:0] addr;
    input [31:0] data;
    begin
      @(negedge clk_i);
      adr_i = addr;
      dat_i = data;
      sel_i = 4'hF;
      we_i  = 1'b1;
      cyc_i = 1'b1;
      stb_i = 1'b1;

      do @(posedge clk_i);
      while (ack_o == 1'b0);

      @(negedge clk_i);
      cyc_i = 1'b0;
      stb_i = 1'b0;
      we_i  = 1'b0;
      adr_i = 32'd0;
      dat_i = 32'd0;
    end
  endtask

  task wb_read;
    input  [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk_i);
      adr_i = addr;
      dat_i = 32'd0;
      sel_i = 4'hF;
      we_i  = 1'b0;
      cyc_i = 1'b1;
      stb_i = 1'b1;

      do @(posedge clk_i);
      while (ack_o == 1'b0);

      #1 data = dat_o;

      @(negedge clk_i);
      cyc_i = 1'b0;
      stb_i = 1'b0;
      adr_i = 32'd0;
    end
  endtask

  task reset_dut;
    begin
      rst_i = 1'b1;
      cyc_i = 1'b0;
      stb_i = 1'b0;
      we_i  = 1'b0;
      adr_i = 32'd0;
      dat_i = 32'd0;
      pwm_fault = 1'b0;

      repeat (4) @(posedge clk_i);
      rst_i = 1'b0;
      repeat (2) @(posedge clk_i);

      // Habilita o clock interno do timer.
      wb_write(GCLK, 32'd1);
    end
  endtask

  task check_equal;
    input [255:0] nome;
    input [31:0]  obtido;
    input [31:0]  esperado;
    begin
      if (obtido !== esperado) begin
        erros = erros + 1;
        $display("[ERRO] %0s | esperado=%0d obtido=%0d",
                 nome, esperado, obtido);
      end else begin
        $display("[OK]   %0s | valor=%0d", nome, obtido);
      end
    end
  endtask

  task check_equal_int;
    input [255:0] nome;
    input integer obtido;
    input integer esperado;
    begin
      if (obtido != esperado) begin
        erros = erros + 1;
        $display("[ERRO] %0s | esperado=%0d obtido=%0d",
                 nome, esperado, obtido);
      end else begin
        $display("[OK]   %0s | valor=%0d", nome, obtido);
      end
    end
  endtask

  task configura_timer;
    input [31:0] cfg_val;
    input [31:0] reload_val;
    input [31:0] pr_val;
    begin
      wb_write(CTRL, 32'd0);
      wb_write(RELOAD, reload_val);
      wb_write(PR, pr_val);
      wb_write(CMPX, 32'd3);
      wb_write(CMPY, 32'd5);
      wb_write(CFG, cfg_val);
      wb_write(IC, 32'h7);
      wb_write(IM, 32'h7);
      wb_write(CTRL, 32'd1);
    end
  endtask

  task espera_tmr_valor;
    input [255:0] nome;
    input [31:0]  esperado;
    integer tentativas;
    begin
      tentativas = 0;

      while ((dut.instance_to_wrap.tmr !== esperado) &&
             (tentativas < 1000)) begin
        @(posedge clk_i);
        #1;
        tentativas = tentativas + 1;
      end

      check_equal(nome, dut.instance_to_wrap.tmr, esperado);
    end
  endtask

  task espera_ris;
    input [2:0] bits_esperados;
    input [255:0] nome;
    integer tentativas;
    begin
      tentativas = 0;
      ris_lido = 32'd0;

      while (((ris_lido[2:0] & bits_esperados) != bits_esperados) &&
             (tentativas < 300)) begin
        wb_read(RIS, ris_lido);
        tentativas = tentativas + 1;
      end

      check_equal(nome, {29'd0, ris_lido[2:0] & bits_esperados},
                  {29'd0, bits_esperados});
    end
  endtask

  task mede_intervalo_pr;
    input [31:0] pr_val;
    integer limite;
    begin
      // Descarta a primeira mudanca para medir em regime.
      tmr_antigo = dut.instance_to_wrap.tmr;
      limite = 0;
      while ((dut.instance_to_wrap.tmr === tmr_antigo) && (limite < 1000)) begin
        @(posedge clk_i);
        #1;
        limite = limite + 1;
      end

      // Mede quantos clocks leva ate a proxima mudanca.
      tmr_antigo = dut.instance_to_wrap.tmr;
      ciclos_medidos = 0;
      while ((dut.instance_to_wrap.tmr === tmr_antigo) &&
             (ciclos_medidos < 1000)) begin
        @(posedge clk_i);
        #1;
        ciclos_medidos = ciclos_medidos + 1;
      end

      check_equal_int("Intervalo medido deve ser PR+1",
                      ciclos_medidos, pr_val + 1);
    end
  endtask

  task testa_up_com_pr;
    input [31:0] pr_val;
    begin
      $display("\n--- UP periodico com PR=%0d ---", pr_val);
      reset_dut();
      configura_timer(CFG_PERIODIC_UP, 32'd8, pr_val);

      mede_intervalo_pr(pr_val);
      espera_tmr_valor("UP chega em 1", 32'd1);
      espera_tmr_valor("UP chega em 2", 32'd2);
      espera_tmr_valor("UP chega em 3", 32'd3);
      espera_tmr_valor("UP chega em 4", 32'd4);

      // Confere que as flags de interrupcao ainda aparecem mesmo variando PR.
      espera_ris(IRQ_MX, "PR variado: CMPX gerou MX");
      espera_ris(IRQ_MY, "PR variado: CMPY gerou MY");
      espera_ris(IRQ_TO, "PR variado: limite gerou TO");

      wb_read(RIS, ris_lido);
      check_equal("RIS final tem TO, MX e MY", ris_lido & 32'h7, 32'h7);
    end
  endtask

  task testa_down_com_pr;
    input [31:0] pr_val;
    begin
      $display("\n--- DOWN periodico com PR=%0d ---", pr_val);
      reset_dut();
      configura_timer(CFG_PERIODIC_DOWN, 32'd4, pr_val);

      mede_intervalo_pr(pr_val);
      espera_tmr_valor("DOWN carrega RELOAD=4", 32'd4);
      espera_tmr_valor("DOWN chega em 3", 32'd3);
      espera_tmr_valor("DOWN chega em 2", 32'd2);
      espera_tmr_valor("DOWN chega em 1", 32'd1);
      espera_tmr_valor("DOWN chega em 0", 32'd0);
      espera_ris(IRQ_TO, "DOWN com PR variado: limite inferior gerou TO");
    end
  endtask

  task testa_up_down_com_pr;
    input [31:0] pr_val;
    begin
      $display("\n--- UP/DOWN periodico com PR=%0d ---", pr_val);
      reset_dut();
      configura_timer(CFG_PERIODIC_UD, 32'd4, pr_val);

      mede_intervalo_pr(pr_val);
      espera_tmr_valor("UP/DOWN sobe para 1", 32'd1);
      espera_tmr_valor("UP/DOWN sobe para 2", 32'd2);
      espera_tmr_valor("UP/DOWN sobe para 3", 32'd3);
      espera_tmr_valor("UP/DOWN chega em 4", 32'd4);
      espera_tmr_valor("UP/DOWN desce para 3", 32'd3);
      espera_tmr_valor("UP/DOWN desce para 2", 32'd2);
      espera_tmr_valor("UP/DOWN desce para 1", 32'd1);
      espera_tmr_valor("UP/DOWN chega em 0", 32'd0);
    end
  endtask

  initial begin
    $dumpfile("tb_timer_wb_pr_variado_simples.vcd");
    $dumpvars(0, tb_timer_wb_pr_variado_simples);

    $display("\n============================================================");
    $display("TESTE COM PR FIXO");
    $display("============================================================");

    testa_up_com_pr(32'd0);
    testa_up_com_pr(32'd1);
    testa_up_com_pr(32'd4);
    testa_up_com_pr(32'd9);

    testa_down_com_pr(32'd2);
    testa_up_down_com_pr(32'd3);

    $display("\n============================================================");
    $display("TESTE COM PR RANDOMIZADO");
    $display("============================================================");

    // Valores aleatorios pequenos para a simulacao nao demorar.
    for (i = 0; i < 5; i = i + 1) begin
      pr_random = $urandom_range(0, 10);
      testa_up_com_pr(pr_random);
    end

    $display("\n=== RESUMO ===");
    if (erros == 0) begin
      $display("[PASSOU] O timer funcionou com PR fixo e PR randomizado.");
    end else begin
      $display("[FALHOU] Quantidade de erros: %0d", erros);
    end

    $finish;
  end

endmodule

`default_nettype wire
