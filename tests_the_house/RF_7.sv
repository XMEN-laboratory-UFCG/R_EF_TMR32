`timescale 1ns/1ps
// ============================================================================
// Testbench para testar cada registrador do EF_TMR32_WB individualmente.
//
// Registradores comuns de leitura/escrita:
//   RELOAD, PR, CMPX, CMPY, CTRL, CFG,
//   PWM0CFG, PWM1CFG, PWMDT, PWMFC e IM.
//
// Registradores especiais:
//   TMR  : somente leitura; escrita nao altera o contador.
//   RIS  : somente leitura do status bruto; escrita nao altera as flags.
//   MIS  : somente leitura de RIS & IM; escrita nao altera o valor.
//   IC   : escrita com 1 limpa flags; volta automaticamente para zero.
//   GCLK : aceita escrita, mas nao esta no mux de leitura dat_o do wrapper.
//          Por isso, sua escrita e conferida internamente neste TB.
// ============================================================================

module tb_timer_wb_registradores_simples;

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

  localparam [31:0] TMR     = 32'h0000_0000;
  localparam [31:0] RELOAD  = 32'h0000_0004;
  localparam [31:0] PR      = 32'h0000_0008;
  localparam [31:0] CMPX    = 32'h0000_000C;
  localparam [31:0] CMPY    = 32'h0000_0010;
  localparam [31:0] CTRL    = 32'h0000_0014;
  localparam [31:0] CFG     = 32'h0000_0018;
  localparam [31:0] PWM0CFG = 32'h0000_001C;
  localparam [31:0] PWM1CFG = 32'h0000_0020;
  localparam [31:0] PWMDT   = 32'h0000_0024;
  localparam [31:0] PWMFC   = 32'h0000_0028;
  localparam [31:0] IM      = 32'h0000_FF00;
  localparam [31:0] MIS     = 32'h0000_FF04;
  localparam [31:0] RIS     = 32'h0000_FF08;
  localparam [31:0] IC      = 32'h0000_FF0C;
  localparam [31:0] GCLK    = 32'h0000_FF10;

  integer erros = 0;
  integer tentativas;
  reg [31:0] valor_lido;

  EF_TMR32_WB #(
    .PRW(16)
  ) dut (
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

  task wb_read;
    input  [31:0] addr;
    output [31:0] data;
    begin
      @(negedge clk_i);
      adr_i = addr;
      dat_i = 0;
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
      adr_i = 0;
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

      // Afasta os valores de comparacao do TMR=0 e limpa flags que podem
      // aparecer porque CMPX, CMPY e RELOAD tambem iniciam em zero.
      wb_write(RELOAD, 32'd100);
      wb_write(CMPX, 32'd101);
      wb_write(CMPY, 32'd102);
      wb_write(IC, 32'h7);
      repeat (3) @(posedge clk_i);
    end
  endtask

  task check_equal;
    input [255:0] nome;
    input [31:0]  obtido;
    input [31:0]  esperado;
    begin
      if (obtido !== esperado) begin
        erros = erros + 1;
        $display("[ERRO] %0s | esperado=0x%08h obtido=0x%08h",
                 nome, esperado, obtido);
      end else begin
        $display("[OK]   %0s | valor=0x%08h", nome, obtido);
      end
    end
  endtask

  task testa_leitura_escrita;
    input [255:0] nome;
    input [31:0] addr;
    input [31:0] valor_escrito;
    input [31:0] valor_esperado;
    begin
      wb_write(addr, valor_escrito);
      wb_read(addr, valor_lido);
      check_equal(nome, valor_lido, valor_esperado);
    end
  endtask

  initial begin
    $dumpfile("tb_timer_wb_registradores_simples.vcd");
    $dumpvars(0, tb_timer_wb_registradores_simples);

    $display("\n=== RESET E PREPARACAO ===");
    reset_dut();

    // ----------------------------------------------------------------------
    // Registradores normais de leitura e escrita
    // ----------------------------------------------------------------------
    $display("\n=== REGISTRADORES DE LEITURA E ESCRITA ===");

    testa_leitura_escrita("RELOAD: 32 bits",
                          RELOAD, 32'h1234_5678, 32'h1234_5678);

    // PRW=16: somente os 16 bits inferiores sao implementados.
    testa_leitura_escrita("PR: somente 16 bits com PRW=16",
                          PR, 32'hABCD_1234, 32'h0000_1234);

    testa_leitura_escrita("CMPX: 32 bits",
                          CMPX, 32'h1111_2222, 32'h1111_2222);

    testa_leitura_escrita("CMPY: 32 bits",
                          CMPY, 32'h3333_4444, 32'h3333_4444);

    // CTRL possui 7 bits: CTRL[6:0].
    testa_leitura_escrita("CTRL: somente 7 bits",
                          CTRL, 32'hFFFF_FFFE, 32'h0000_007E);

    // CFG possui 3 bits: CFG[2:0].
    testa_leitura_escrita("CFG: somente 3 bits",
                          CFG, 32'hFFFF_FFFF, 32'h0000_0007);

    // PWM0CFG possui 12 bits.
    testa_leitura_escrita("PWM0CFG: somente 12 bits",
                          PWM0CFG, 32'hABCD_5678, 32'h0000_0678);

    // No wrapper atual, PWM1CFG_REG foi declarado com 16 bits.
    testa_leitura_escrita("PWM1CFG: registrador de 16 bits no wrapper",
                          PWM1CFG, 32'hABCD_5678, 32'h0000_5678);

    // PWMDT possui 8 bits.
    testa_leitura_escrita("PWMDT: somente 8 bits",
                          PWMDT, 32'h1234_56A5, 32'h0000_00A5);

    // PWMFC possui 16 bits.
    testa_leitura_escrita("PWMFC: somente 16 bits",
                          PWMFC, 32'h1234_A539, 32'h0000_A539);

    // IM possui somente os bits TO, MX e MY.
    testa_leitura_escrita("IM: somente 3 bits",
                          IM, 32'hFFFF_FFFD, 32'h0000_0005);

    // ----------------------------------------------------------------------
    // TMR: leitura permitida, escrita ignorada
    // ----------------------------------------------------------------------
    $display("\n=== TMR: SOMENTE LEITURA ===");

    wb_read(TMR, valor_lido);
    check_equal("TMR inicia parado em zero", valor_lido, 32'd0);

    wb_write(TMR, 32'hAAAA_5555);
    wb_read(TMR, valor_lido);
    check_equal("Escrita em TMR nao altera o contador", valor_lido, 32'd0);

    // ----------------------------------------------------------------------
    // RIS e MIS: escritas nao alteram os registradores
    // ----------------------------------------------------------------------
    $display("\n=== RIS E MIS: STATUS DE LEITURA ===");

    wb_write(RIS, 32'h7);
    wb_read(RIS, valor_lido);
    check_equal("Escrita direta em RIS e ignorada", valor_lido & 32'h7, 0);

    wb_write(MIS, 32'h7);
    wb_read(MIS, valor_lido);
    check_equal("Escrita direta em MIS e ignorada", valor_lido & 32'h7, 0);

    // ----------------------------------------------------------------------
    // GCLK: escrita funciona, mas leitura WB nao foi mapeada no dat_o
    // ----------------------------------------------------------------------
    $display("\n=== GCLK: ESCRITA SEM READBACK WB ===");

    wb_write(GCLK, 32'd1);
    check_equal("GCLK_REG interno recebeu 1", {31'd0, dut.GCLK_REG[0]}, 1);

    wb_read(GCLK, valor_lido);
    check_equal("Leitura WB de GCLK retorna endereco nao mapeado",
                valor_lido, 32'hDEAD_BEEF);

    // ----------------------------------------------------------------------
    // IC: gera pulso e limpa uma flag real de RIS
    // ----------------------------------------------------------------------
    $display("\n=== IC: LIMPEZA DE INTERRUPCAO ===");

    wb_write(CTRL, 32'd0);
    wb_write(RELOAD, 32'd10);
    wb_write(PR, 32'd0);
    wb_write(CMPX, 32'd2);
    wb_write(CMPY, 32'd100);
    wb_write(CFG, 32'h6);  // UP periodico
    wb_write(IM, 32'h7);
    wb_write(IC, 32'h7);
    wb_write(CTRL, 32'd1);

    tentativas = 0;
    while ((dut.RIS_REG[1] !== 1'b1) && (tentativas < 100)) begin
      @(posedge clk_i);
      #1;
      tentativas = tentativas + 1;
    end

    wb_read(RIS, valor_lido);
    check_equal("CMPX gerou RIS[1] antes da limpeza",
                valor_lido & 32'h2, 32'h2);

    // Para o timer e afasta CMPX antes de limpar, evitando que a flag volte.
    wb_write(CTRL, 32'd0);
    wb_write(RELOAD, 32'd100);
    wb_write(CMPX, 32'd101);
    wb_write(CMPY, 32'd102);
    wb_write(IC, 32'h2);
    repeat (3) @(posedge clk_i);

    wb_read(RIS, valor_lido);
    check_equal("IC=010 limpou RIS[1]", valor_lido & 32'h2, 0);

    wb_read(IC, valor_lido);
    check_equal("IC volta automaticamente para zero", valor_lido & 32'h7, 0);

    // ----------------------------------------------------------------------
    // Endereco inexistente
    // ----------------------------------------------------------------------
    $display("\n=== ENDERECO NAO MAPEADO ===");

    wb_read(32'h0000_1234, valor_lido);
    check_equal("Endereco inexistente retorna DEADBEEF",
                valor_lido, 32'hDEAD_BEEF);

    $display("\n=== RESUMO ===");
    if (erros == 0) begin
      $display("[PASSOU] Todos os registradores foram testados.");
    end else begin
      $display("[FALHOU] Quantidade de erros: %0d", erros);
    end

    $finish;
  end

endmodule

