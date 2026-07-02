//`timescale 1ns/1ps

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

  //  wire       irq;         // não sera usado agr mas existe
   // wire       pwm0, pwm1;  // """"""""""""""""""""""""""""' 

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
        .ack_o(ack_o)
        //.irq(irq)
        //.pwm0(pwm0),
        //.pwm1(pwm1),
        //.pwm_fault(1'b0)
    );

    initial begin

        // começando com zero tudo
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;
        sel_i = 0;
        adr_i = 0;
        dat_i = 0;

        rst_i = 1;
        #50; // ispeera 50ns
        rst_i = 0; // no reset
        #20; // ispera 20ns pra isperar um tico

        $display("PR");
        @(posedge clk_i);
        adr_i = 32'h0000_0008;
        dat_i = 32'h0000_0000;
        sel_i = 4'b1111;
        we_i  = 1;
        stb_i = 1;
        cyc_i = 1;

        wait(ack_o == 1);
        #10;

        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        $display("alvo teto sendo inserido (RELOAD");

        @(posedge clk_i);
        adr_i = 32'h0000_0004; // endereço do reload
        dat_i = 32'd100; // valor do reload
        sel_i = 4'b1111; // habilita todos os bitis inteiros
        we_i = 1; // avisa que é iscrita
        stb_i = 1; // aqui
        cyc_i = 1; // aqui^2 é o handshake do wb. tem que os dois ser 1

        wait(ack_o == 1); // espera valida que foi lido/recebido o solicitamento
        #10;

        @(posedge clk_i);
        cyc_i = 0; // desabilita o handshake
        stb_i = 0; // desabilita o handshake
        we_i  = 0; // so leia

        $display("papocando o timer via o registra_dor CTRL");

        @(posedge clk_i);
        adr_i = 32'h0000_0014; // endereço do CTRL
        dat_i = 32'h0000_0001; // habilita o timer
        sel_i = 4'b1111; // habilita todos os bitis inteiros
        we_i = 1; // avisa que é iscrita
        stb_i = 1; // aqui
        cyc_i = 1; // aqui^2 é o handshake do wb. tem que os dois ser 1

        wait(ack_o == 1); // espera valida que foi lido/recebido o solicitamento
        #10;
        @(posedge clk_i);
        cyc_i = 0; // desabilita o handshake
        stb_i = 0; // desabilita o handshake
        we_i  = 0; // so leia
        
        #200; // ispere 100ns. the timer estar rodano

        $display("oia la o valor atual no cabra");

        @(posedge clk_i);
        adr_i = 32'h0000_0000; // endereço do valor atual
        sel_i = 4'b1111; // habilita todos os bitis inteiros
        we_i = 0; // ser intelectual na leitura
        cyc_i = 1; // aqui^2 é o handshake do wb. tem que os dois ser 1
        stb_i = 1; // aqui
        wait(ack_o == 1); // espera valida que foi lido/recebido o solicitamento
        #1;
        @(posedge clk_i);
        $display("valor lido: %0d", dat_o); // imprime resposta
        cyc_i = 0; // desabilita o handshake
        stb_i = 0; // desabilita o handshake
        
        $display("finishi\n"); // como não houve direcionamento, ele nao foi para lugar algum.

        $display("parte doix bb (UPI)");

        @(posedge clk_i);
        adr_i = 32'h0000_0018; // CFG entedeçoo
        dat_i = 32'h0000_0006; // up model periodico
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #10;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        #300; // conte um bucado

        $display("veremos esse cabra dnv");
        @(posedge clk_i);
        adr_i = 32'h0000_0000;
        sel_i = 4'b1111;
        we_i  = 0;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        $display("aqui ele: %0d", dat_o);
        cyc_i = 0;
        stb_i = 0;

        $display("===========LIMPEZA========");
        // começando com zero tudo
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;
        sel_i = 0;
        adr_i = 0;
        dat_i = 0;

        rst_i = 1;
        #50; // ispeera 50ns
        rst_i = 0; // no reset
        #20; // ispera 20ns pra isperar um tico

        // inciando de voco

        $display("PR");
        @(posedge clk_i);
        adr_i = 32'h0000_0008;
        dat_i = 32'h0000_0000;
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0); // esoerar bauxar a mao
        #10;

        $display("reload");
        adr_i = 32'h0000_0004;
        dat_i = 32'd100;
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0);
        #10;

        $display("CFG, ups");
        @(posedge clk_i);
        adr_i = 32'h0000_0018;
        dat_i = 32'h0000_0006; // up periodic ou 32'h0000_0110;
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0);
        #10;

        $display("papoca abençoado (CTRL)");
        @(posedge clk_i);
        adr_i = 32'h0000_0014;
        dat_i = 32'h0000_0001;
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0);
        #10;

        $display("esse abençoado pegou?????");

        repeat(5) begin
          #1; // conta ai infiliz
          @(posedge clk_i);
          adr_i = 32'h0000_0000;
          sel_i = 4'b1111;
          we_i  = 0;
          cyc_i = 1;
          stb_i = 1;

          wait(ack_o == 1);
          #1;
          $display("lido, up, %0d", dat_o);

          @(posedge clk_i);
          cyc_i = 0;
          stb_i = 0;
          wait(ack_o == 0);
          #10;

        end

        $display("inverte CFG");

        @(posedge clk_i);
        adr_i = 32'h0000_0014;
        dat_i = 32'h0000_0000; // pausa
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0);
        #10;

        $display("paixte 3 (dwon model periodico)");
        @(posedge clk_i);
        adr_i = 32'h0000_0018;
        dat_i = 32'h0000_0001;
        sel_i = 4'b1111;
        we_i  = 1;
        cyc_i = 1;
        stb_i = 1;

        wait(ack_o == 1);
        #1;
        @(posedge clk_i);
        cyc_i = 0;
        stb_i = 0;
        we_i  = 0;

        wait(ack_o == 0);
        #10;

        $display("[7] Papocando o timer de novo (CTRL = 1)");
        @(posedge clk_i);
        adr_i = 32'h0000_0014; 
        dat_i = 32'h0000_0001; 
        sel_i = 4'b1111; 
        we_i = 1; stb_i = 1; cyc_i = 1; 

        wait(ack_o == 1);
        @(posedge clk_i);
        cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0);
        #10;
        /// daqui pra baixo ta bixado
        

        // ==========================================
        $display("\n--- VEREMOS ESSE CABRA DESCENDO ---");
        
        repeat(5) begin
            #1; // Deixa ele descer um bucado

            @(posedge clk_i);
            adr_i = 32'h0000_0000;
            sel_i = 4'b1111;
            we_i  = 0; 
            cyc_i = 1; stb_i = 1;

            wait(ack_o == 1); // 1. Chip diz: Dado ta pronto!
            #1;               // 2. Respiro do simulador pra imprimir limpo
            $display("Valor lido (DOWN): %0d", dat_o);

            @(posedge clk_i);
            cyc_i = 0; stb_i = 0; // 3. Desabilita
            wait(ack_o == 0);
            #10;
        end

        // ==========================================
        $display("\n=========== LIMPANDO PARA O TESTE FINAL ========");
        cyc_i = 0; stb_i = 0; we_i = 0;
        
        rst_i = 1; #50; rst_i = 0; #20; 

        // 1. O MOTOR
        @(posedge clk_i);
        adr_i = 32'h0000_0008; dat_i = 32'h0000_0000; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 2. O TETO (RELOAD = 100)
        @(posedge clk_i);
        adr_i = 32'h0000_0004; dat_i = 32'd100; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 3. A DIREÇÃO (CFG = UP/DOWN)
        $display("Configurando CFG para a Montanha-Russa (UP/DOWN)");
        @(posedge clk_i);
        adr_i = 32'h0000_0018; 
        
        // Se o DOWN foi 4 e o UP foi 2 (ou 6), o UP/DOWN geralmente é o 6 ou o 2 na Efabless. 
        // Vamos testar o 6! (Se ele só subir, a gente troca pro 2 depois).
        dat_i = 32'h0000_0006; 
        
        sel_i = 4'b1111;
        we_i  = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 4. LIGANDO A CHAVE (CTRL = 1)
        $display("Papocando o motor!");
        @(posedge clk_i);
        adr_i = 32'h0000_0014; dat_i = 32'h0000_0001; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1; 
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // ==========================================
        $display("\n--- OIA O CABRA SUBINDO E DESCENDO A LADEIRA ---");
        
        // Vamos tirar 15 fotos agora, com intervalos menores pra ver a curva
        repeat(15) begin
            #100; // Tempo passando

            @(posedge clk_i);
            adr_i = 32'h0000_0000; sel_i = 4'b1111;
            we_i  = 0; cyc_i = 1; stb_i = 1;

            wait(ack_o == 1); 
            #1;               
            $display("Valor lido (UP/DOWN): %0h", dat_o);

            @(posedge clk_i);
            cyc_i = 0; stb_i = 0; 
            wait(ack_o == 0);
            #10;
        end

        $display("\nTeste do UP/DOWN finalizado!\n");
        // ==========================================

        // ==========================================
        $display("\n=========== PREPARANDO O TIRO UNICO (ONE-SHOT) ========");

        // 1. O MOTOR (PR = 0)
        @(posedge clk_i); adr_i = 32'h0000_0008; dat_i = 32'h0000_0000; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 2. O TETO (RELOAD = 100)
        @(posedge clk_i); adr_i = 32'h0000_0004; dat_i = 32'd100; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 3. A DIREÇÃO (CFG = 0 -> UP One-Shot)
        $display("Configurando CFG para One-Shot (0x0)");
        @(posedge clk_i); adr_i = 32'h0000_0018; dat_i = 32'h0000_0000; sel_i = 4'b1111;
        we_i  = 1; stb_i = 1; cyc_i = 1;
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // 4. LIGANDO A CHAVE (CTRL = 1)
        $display("Papocando o motor pela 1a vez!");
        @(posedge clk_i); adr_i = 32'h0000_0014; dat_i = 32'h0000_0001; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1; 
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // ==========================================
        $display("\n--- DEIXANDO ELE BATER NO TETO E MORRER ---");
        #1500; // Tempo GIGANTE pro cabra cansar e bater no limite de 100
        
        // Vamos ler 3 vezes pra provar que ele travou
        repeat(3) begin
            #50;
            @(posedge clk_i); adr_i = 32'h0000_0000; sel_i = 4'b1111;
            we_i  = 0; cyc_i = 1; stb_i = 1;
            wait(ack_o == 1); #1;               
            $display("Valor travado?: %0d", dat_o);
            @(posedge clk_i); cyc_i = 0; stb_i = 0; wait(ack_o == 0); #10;
        end

        // ==========================================
        $display("\n--- DANDO O CHUTE DE RE-START (TS = 1 -> TS = 0) ---");
        
        // Escreve 3 (Bit 0 e Bit 1 ligados)
        @(posedge clk_i); adr_i = 32'h0000_0014; dat_i = 32'h0000_0003; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1; 
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        // Escreve 1 de novo (Desliga o Bit 1, mantem o motor ligado)
        @(posedge clk_i); adr_i = 32'h0000_0014; dat_i = 32'h0000_0001; sel_i = 4'b1111;
        we_i = 1; stb_i = 1; cyc_i = 1; 
        wait(ack_o == 1); @(posedge clk_i); cyc_i = 0; stb_i = 0; we_i = 0;
        wait(ack_o == 0); #10;

        $display("\n--- OIA ELE RESSUSCITANDO ---");
        // Lendo pra ver ele subindo do zero de novo
        repeat(5) begin
            #150;
            @(posedge clk_i); adr_i = 32'h0000_0000; sel_i = 4'b1111;
            we_i  = 0; cyc_i = 1; stb_i = 1;
            wait(ack_o == 1); #1;               
            $display("Valor ressuscitado: %0d", dat_o);
            @(posedge clk_i); cyc_i = 0; stb_i = 0; wait(ack_o == 0); #10;
        end
        // ==========================================


        $finish;
       
    end

endmodule