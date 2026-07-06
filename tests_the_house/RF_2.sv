`timescale 1ns/1ps

// sel_i, condenado.
// "select" é o "byte enable" do WB. 32bits divididos em 4bytes com sel de 4btis
//sel_i[0] = bule com bits de 0 à 7;
//sel_i[1] = bule com bits de 8 à 15;
//sel_i[3] = bule com bits de 24 à 31;

// sempre está em 4'b1111 para facilitar a vida do homem.
// como os registros possuem 32bits, ele considera válida toda palavra mandada.
// ex: dat_i = 32'd100 (reload), o bixo recebe os 32bits de uma vez so.
// com sel_i diferente, tem de alterar os valores de escrita/leitura.
// se sel_i = 4'b0001, ele so lerá nos 8 bits menos significatiso e ignora o resto.

// VERIFICA O CMPx E CMPy E O TO

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
    wire       pwm0;
    wire       pwm1;

    reg        pwm_fault;

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
            cyc_i = 1; //barramento ativado[1];
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
            //wb_escrita(32'h0000_FF10, 32'b00000_0001);
            wb_escrita(32'h0000_0008, 32'd0); // PR
            wb_escrita(32'h0000_0004, reload);
            //wb_escrita(32'h0000_000C, cmpx);
            //wb_escrita(32'h0000_FF00, im);
            wb_escrita(32'h0000_0018, cfg);
            //wb_escrita(32'h0000_0010, cmpy);
            //wb_escrita(32'h0000_0014, ctrl);

        end
    endtask

    task ligar_timer; // CTRL
        begin
            wb_escrita(32'h0000_0014, 32'b0000_0001); // ou _0000
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


        $display("TESTE_1");

        reseta();
        //limpa_interrup(3'b111);

        //reload, cfg,
        configuracao_timer(32'd15, 3'b110);
        // configura CMPX e IM
        wb_escrita(32'h0000_000C, 3'b101); // CMPX
        wb_escrita(32'h0000_FF00, 3'b010); // IM
        limpa_interrup(3'b010);
        ligar_timer();
        repeat(20)
        begin
            leitura(32'h0000_0000); // cont
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        limpa_interrup(3'b010);
        reseta();

        $display("\n TEST_2");

        limpa_interrup(3'b111); // garantia

        // reload, cfg
        configuracao_timer(32'd15, 3'b101);
        // config CMPY e IM (respec)
        wb_escrita(32'h0000_0010, 3'b100);
        wb_escrita(32'h0000_FF00, 3'b100);
        limpa_interrup(3'b100);
        ligar_timer();
        repeat(20)
        begin
            leitura(32'h0000_0000); // cont
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        limpa_interrup(3'b100);
        reseta();

        $display("\n TEST_3"); // BIXADODOODODD
        limpa_interrup(3'b111);

        //reload, cfg
        configuracao_timer(32'd15, 3'b110);
        // config TO e IM (respecti)
        //wb_escrita(32'h0000_0000, 3'b111);
        wb_escrita(32'h0000_FF00, 3'b001); // TO é acionado quando o timer chega no valor do RELOAD
        limpa_interrup(3'b111);
        ligar_timer();
        repeat(20)
        begin
            leitura(32'h0000_0000); // cont
            $display("Tempo: %0t | Count = %0d | IRQ = %b", $time, dat_o, IRQ);
        end
        limpa_interrup(3'b001);
        reseta();




        $finish;
    end

endmodule
