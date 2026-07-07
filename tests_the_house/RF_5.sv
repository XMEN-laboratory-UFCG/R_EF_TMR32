`timescale 1ns/1ps

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


endmodule
