//`timescale 1ns/1ps

// Um fato interessante: O 'sel_i' pode ser ignorado completamente.

module tb_contador_simple_man;

    // clk e rst
    reg clk_i = 0;
    reg rst_i = 0;

    always #5 clk_i = ~clk_i; // inverte a cada 5ns


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

        input [32:0] pr;
        input [31:0] reload;
        //input [31:0] cmpx;
        //input [31:0] im;
        input [31:0] cfg;
        //input [31:0] cmpy;
        //input [31:0] ctrl;

        begin
            wb_escrita(32'h0000_0008, pr); // PR
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

        $display("TESTE_1: PR = 0");
        reseta();
        // pr, reload, cgf
        configuracao_timer(32'd0, 32'd15, 3'b110); // periodico up
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("TEMPo = %0t | TMR = %0d", $time, dat_o);
        end
        #10;
        reseta();
        #10;

        $display("\nTESTE_2: PR = 1");
        reseta();
        configuracao_timer(32'd1, 32'd15, 3'b110);
        ligar_timer(32'h0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("TEMPO = %0t | TMR = %0d", $time, dat_o);
        end
        #10;
        reseta();
        #10;

        $display("\nTESTE_3: PR = 5"); // Pr+1
        configuracao_timer(32'd4, 32'd15, 3'b110);
        ligar_timer(32'b0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("TEMPO = 0%t | TMR = %0d", $time, dat_o);
        end
        #10;
        reseta();
        #10;

        $display("\nTESTE_4: PR = 10"); // Pr + 1
        configuracao_timer(32'd9, 32'd15, 3'b110);
        ligar_timer(32'b0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("TEMPO = 0%t | TMR = %0d", $time, dat_o);
        end
        #10;
        reseta();
        #10;

        $display("\nTESTE_5: PR = 5");
        configuracao_timer(32'd4, 32'd15, 3'b101); // periodico down
        ligar_timer(32'b0000_0001);
        repeat(25)
        begin
            leitura(32'h0000_0000);
            $display("TEMPO = 0%t | TMR = %0d", $time, dat_o);
        end
        #10;
        reseta();
        #10;



        $finish;

    end

endmodule
