`timescale 1ns/1ps
`default_nettype none

// ============================================================================
// TB simples para entender CTRL e CFG no EF_TMR32_WB
//
// Ideia principal:
//
//   CTRL = controle geral
//     CTRL[0] = TE = liga/desliga o timer
//     CTRL[1] = TS = restart/start usado principalmente em one-shot
//     CTRL[2] em diante = sinais ligados ao PWM
//
//   CFG = configuracao da contagem
//     CFG[2]   = 1 periodico, 0 one-shot
//     CFG[1:0] = direcao
//                2'b10 = UP
//                2'b01 = DOWN
//                2'b11 = UP/DOWN
//
// Conclusao esperada:
//   CTRL e CFG NAO sao a mesma coisa.
//   CFG escolhe "como contar".
//   CTRL escolhe "se o timer esta ligado".
// ============================================================================

module tb_timer_wb_ctrl_cfg_simples;

  reg clk_i = 0;
  reg rst_i = 1;

  reg  [31:0] adr_i = 0;
  reg  [31:0] dat_i = 0;
  wire [31:0] dat_o;
  reg  [3:0]  sel_i = 4'hF;
  reg         cyc_i = 0;
  reg         stb_i = 0;
  reg         we_i  = 0;
  wire        ack_o;

  wire IRQ;
  wire pwm0;
  wire pwm1;
  reg  pwm_fault = 0;

  localparam RELOAD = 32'h0000_0004;
  localparam PR     = 32'h0000_0008;
  localparam CTRL   = 32'h0000_0014;
  localparam CFG    = 32'h0000_0018;
  localparam GCLK   = 32'h0000_FF10;

  // Valores de CFG.
  localparam CFG_ONE_UP   = 32'h2; // 3'b0_10: one-shot + UP
  localparam CFG_PER_DOWN = 32'h5; // 3'b1_01: periodico + DOWN
  localparam CFG_PER_UP   = 32'h6; // 3'b1_10: periodico + UP
  localparam CFG_PER_UD   = 32'h7; // 3'b1_11: periodico + UP/DOWN

  integer erros = 0;
  reg [31:0] tmr_guardado;

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
      adr_i = 0;
      dat_i = 0;
    end
  endtask

  task reset_dut;
    begin
      rst_i = 1'b1;
      cyc_i = 0;
      stb_i = 0;
      we_i  = 0;
      adr_i = 0;
      dat_i = 0;
      pwm_fault = 0;

      repeat (4) @(posedge clk_i);
      rst_i = 1'b0;
      repeat (2) @(posedge clk_i);

      // Libera o clock interno do timer.
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
        $display("[OK]   %0s | TMR=%0d", nome, obtido);
      end
    end
  endtask

  task check_diferente;
    input [255:0] nome;
    input [31:0]  a;
    input [31:0]  b;
    begin
      if (a === b) begin
        erros = erros + 1;
        $display("[ERRO] %0s | TMR nao mudou: %0d", nome, a);
      end else begin
        $display("[OK]   %0s | mudou de %0d para %0d", nome, b, a);
      end
    end
  endtask

  task configura_base;
    input [31:0] cfg_val;
    begin
      wb_write(CTRL, 32'd0);
      wb_write(RELOAD, 32'd4);
      wb_write(PR, 32'd10);
      wb_write(CFG, cfg_val);
    end
  endtask

  task liga_timer;
    begin
      // CTRL[0]=1 liga o timer.
      wb_write(CTRL, 32'd1);
    end
  endtask

  task desliga_timer;
    begin
      // CTRL[0]=0 desliga/pausa o timer.
      wb_write(CTRL, 32'd0);
    end
  endtask

  task espera_tmr;
    input [255:0] nome;
    input [31:0] esperado;
    integer tentativas;
    begin
      tentativas = 0;
      while ((dut.instance_to_wrap.tmr !== esperado) &&
             (tentativas < 500)) begin
        @(posedge clk_i);
        #1;
        tentativas = tentativas + 1;
      end

      check_equal(nome, dut.instance_to_wrap.tmr, esperado);
    end
  endtask

  task confere_parado;
    input [255:0] nome;
    begin
      tmr_guardado = dut.instance_to_wrap.tmr;
      repeat (80) @(posedge clk_i);
      #1;
      check_equal(nome, dut.instance_to_wrap.tmr, tmr_guardado);
    end
  endtask

  initial begin
    $dumpfile("tb_timer_wb_ctrl_cfg_simples.vcd");
    $dumpvars(0, tb_timer_wb_ctrl_cfg_simples);

    // ============================================================
    // TESTE 1: CFG sozinho nao liga o timer
    // ============================================================
    $display("\n=== TESTE 1: CFG sozinho NAO liga o timer ===");
    reset_dut();
    configura_base(CFG_PER_UP);

    // Aqui CFG diz "UP periodico", mas CTRL ainda esta 0.
    // Resultado esperado: TMR fica parado.
    confere_parado("CFG=UP periodico, mas CTRL=0");

    // ============================================================
    // TESTE 2: CTRL liga o timer
    // ============================================================
    $display("\n=== TESTE 2: CTRL[0]=1 liga o timer ===");
    liga_timer();

    espera_tmr("Com CTRL=1, UP chega em 1", 32'd1);
    espera_tmr("Com CTRL=1, UP chega em 2", 32'd2);

    // ============================================================
    // TESTE 3: CTRL=0 pausa o timer
    // ============================================================
    $display("\n=== TESTE 3: CTRL[0]=0 pausa o timer ===");
    desliga_timer();
    confere_parado("Depois de CTRL=0, TMR fica parado");

    // ============================================================
    // TESTE 4: escrever o mesmo numero em CTRL e CFG nao e a mesma coisa
    // ============================================================
    $display("\n=== TESTE 4: CTRL e CFG nao interpretam os bits do mesmo jeito ===");
    reset_dut();

    // CFG=6 significa UP periodico.
    wb_write(RELOAD, 32'd4);
    wb_write(PR, 32'd10);
    wb_write(CFG, CFG_PER_UP);

    // Mas CTRL=6 NAO significa UP periodico.
    // 6 = 3'b110, logo CTRL[0]=0.
    // Como CTRL[0] e o enable, o timer fica desligado.
    wb_write(CTRL, 32'd6);
    confere_parado("CTRL=6 nao liga o timer, pois CTRL[0]=0");

    // Agora sim: CTRL=1 liga.
    wb_write(CTRL, 32'd1);
    espera_tmr("Depois de CTRL=1, timer comeca", 32'd1);

    // ============================================================
    // TESTE 5: CFG muda a direcao da contagem
    // ============================================================
    $display("\n=== TESTE 5: CFG muda a direcao ===");

    reset_dut();
    configura_base(CFG_PER_DOWN);
    liga_timer();
    espera_tmr("CFG=DOWN: primeiro carrega RELOAD=4", 32'd4);
    espera_tmr("CFG=DOWN: depois vai para 3", 32'd3);
    espera_tmr("CFG=DOWN: depois vai para 2", 32'd2);

    reset_dut();
    configura_base(CFG_PER_UD);
    liga_timer();
    espera_tmr("CFG=UP/DOWN: sobe para 1", 32'd1);
    espera_tmr("CFG=UP/DOWN: sobe para 2", 32'd2);
    espera_tmr("CFG=UP/DOWN: sobe para 3", 32'd3);
    espera_tmr("CFG=UP/DOWN: chega em 4", 32'd4);
    espera_tmr("CFG=UP/DOWN: depois desce para 3", 32'd3);

    // ============================================================
    // TESTE 6: CFG[2] muda periodico vs one-shot
    // ============================================================
    $display("\n=== TESTE 6: CFG[2] muda periodico vs one-shot ===");

    reset_dut();
    configura_base(CFG_ONE_UP);
    liga_timer();
    espera_tmr("ONE-SHOT UP: chega em 1", 32'd1);
    espera_tmr("ONE-SHOT UP: chega em 2", 32'd2);
    espera_tmr("ONE-SHOT UP: chega em 3", 32'd3);
    espera_tmr("ONE-SHOT UP: chega no limite 4", 32'd4);
    confere_parado("ONE-SHOT UP para no limite");

    $display("\n=== RESUMO ===");
    if (erros == 0) begin
      $display("[PASSOU] CTRL e CFG tiveram comportamentos diferentes e esperados.");
    end else begin
      $display("[FALHOU] Quantidade de erros: %0d", erros);
    end

    $finish;
  end

endmodule

`default_nettype wire
