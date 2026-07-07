//`timescale 1ns/1ps

// Um fato interessante: O 'sel_i' pode ser ignorado completamente.

module tb_contador_simple_man;

    // clk e rst
    reg clk_i = 0;
    reg rst_i = 0;

    always #5 clk_i = ~clk_i; // gogo inverte a cada 5ns


    //wb invocamentos
    reg [31:0] adr_i;
    reg [31:0] dat_i;
    reg [3:0]  sel_i;  // select do wb. quais bytes valem? (1111 for 32 bits)
    reg        we_i;   // 1 = iscreve, 0 = ler
    reg        stb_i;  // strobe
    reg        cyc_i;  // cycle

    wire [31:0] dat_o; // datos lidos do timer
    wire        ack_o; // acknowledge (valida o recebimento)

    // interupcion

    wire       IRQ;
    wire       pwm0, pwm1;

    //duts

    EF_TMR32_WB dut (
        .clk_i(clk_i),
        .rst_i(rst_i),

        .adr_i(adr_i),
        .dat_i(dat_i),
        .we_i(we_i),
        .stb_i(stb_i),
        .cyc_i(cyc_i),
        .sel_i(sel_i),

        .dat_o(dat_o),
        .ack_o(ack_o),
        .IRQ(IRQ),
        .pwm0(pwm0),
        .pwm1(pwm1),
        .pwm_fault(1'b0)
    );

    task wb_escrita;

        input [31:0] endereco;
        input [31:0] dado;

        begin
            @(posedge clk_i);

            adr_i = endereco;
            dat_i = dado;

            sel_i = 4'b1111;

            we_i  = 1;
            cyc_i = 1; // barramento ativado[1];
            stb_i = 1; // avisa q adr e dat sao validos para o processamento

            wait(ack_o == 1); // avisa que os dados foram recebidos

            @(posedge clk_i);
            we_i  = 0;
            cyc_i = 0;
            stb_i = 0;

            wait(ack_o == 0);
        end
    endtask

    task leitura;
        input [31:0] endereco;

        begin
            @(posedge clk_i);
            adr_i = endereco;

            sel_i = 4'b1111;
            we_i  = 0;
            cyc_i = 1;
            stb_i = 1;

                
            wait(ack_o == 1);

            @(posedge clk_i);
            we_i  = 0;
            cyc_i = 0;
            stb_i = 0;

            wait(ack_o == 0);
        end
    endtask

    task reseta;
        begin
            rst_i = 1;
            #50;
            rst_i = 0;
            #50;
        end
    endtask

    task configuracao_timer;

        input [31:0] reload;
        //input [31:0] cmpx;
        //input [31:0] im;
        input [31:0] cfg;
        //input [31:0] cmpy;
        //input [31:0] ctrl;

        begin
            wb_escrita(32'h0000_0008, 32'd0); // PR
            wb_escrita(32'h0000_0004, reload);
            //wb_iscrita(32'h0000_000C, cmpx);
            //wb_iscrita(32'h0000_FF00, im);
            wb_escrita(32'h0000_0018, cfg);
            //wb_iscrita(32'h0000_0010, cmpy);
            //wb_iscrita(32'h0000_0014, ctrl);
            //wb_iscrita(32'h0000_FF10, 32'b00000_0001); // GCLK

        end
    endtask

    task ligar_timer; // CTRL
        input [31:0] controle;
        begin
            wb_escrita(32'h0000_0014, controle);
        end
    endtask

    task limpa_interrup;
        input [31:0] param;
        begin
            wb_escrita(32'h0000_FF0C, param);
        end
    endtask


    initial begin

        // começando com zero tudo
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;
        sel_i = 0;
        adr_i = 0;
        dat_i = 0;

        // TESTE_1
        $display("TESTE_1; VALIDANDO CONTADOR PERIODICO CRESCENTE");
        reseta();
        #50;        // espera um pouco.

        //wb_escrita(32'h0000_FF10, 32'b00000_0001); //GCLK
        // configurando o timer
        // reload, cfg
        configuracao_timer(32'd14, 3'b110);
        //#1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        //#1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0b", dat_o);
        //#1;
        ligar_timer(32'h0000_0011); // ativa timer
        #1
        leitura(32'h0000_0014);
        $display("Valor do CTRL: %0b", dat_o);
        #1
        repeat(20)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        // TESTE_2
        $display("\n TESTE_2; VALIDANDO CONTADOR PERIODICO DECRESCENTE");
        reseta();
        configuracao_timer(32'd14, 3'b101);
        #1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        #1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0d", dat_o);
        #1;
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        // TESTE_3
        $display("\n TESTE_3; VALIDANDO CONTADOR ONE-SHOT CRESCENTE");
        reseta();
        configuracao_timer(32'd14, 3'b010);
        #1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        #1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0d", dat_o);
        #1;
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        // TESTE_4
        $display("\n TESTE_4; VALIDANDO CONTADOR ONE-SHOT DECRESCENTE");
        reseta();
        configuracao_timer(32'd14, 3'b001);
        #1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        #1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0d", dat_o);
        #1;
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        $display("\n TESTE_5; VALIDANDO CONTADOR UP/DOWN PERIODICO");
        reseta();
        configuracao_timer(32'd14, 3'b111);
        #1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        #1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0d", dat_o);
        #1;
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        $display("\n TESTE_6; VALIDANDO CONTADOR UP/DOWN ONE-SHOT");
        reseta();
        configuracao_timer(32'd14, 32'h0000_0011);
        #1;
        leitura(32'h0000_0004); // reload
        $display("Valor do reload: %0d", dat_o);
        #1;
        leitura(32'h0000_0018); // cfg
        $display("Valor do cfg: %0d", dat_o);
        #1;
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        reseta();
        #10;

        $finish;
       
    end

endmodule
