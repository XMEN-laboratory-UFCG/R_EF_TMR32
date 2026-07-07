//`timescale 1ns/1ps

// GCLK
// COMANDO: xrun -sv -timescale 1ns/1ps +define+CLKG_GENERIC EF_TMR32_WB.v EF_TMR32.v ef_util_lib.v tb_wb.sv

// verifique o "ef_util_lib.v" na parte onde fala sobre o GCLK. há um else em que se nada for definido, ele 'desconsidera' o GCLK

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

    task clock_gate;
        input [31:0] cgate;
        begin
            wb_escrita(32'h0000_FF10, cgate);
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
        configuracao_timer(32'd15, 3'b110);
        clock_gate(1'b1); // ativo
        ligar_timer();

        repeat(5)
        begin
            leitura(32'h0000_0000);
            $display("\n CONTA = %0d", dat_o);
        end

        clock_gate(1'b0); // desativo
        @(posedge clk_i);
        repeat(10)
        begin
            leitura(32'h0000_0000);
            $display("\n conta agora = %0d", dat_o);
        end

        clock_gate(1'b1); // ativo de novo de onde parou
        @(posedge clk_i);
        repeat(10)
        begin
            leitura(32'h0000_0000);
            $display("\n conta agora agora = %0d", dat_o);
        end

        $display("\n -------------------------------------");


        $finish;
    end

endmodule
