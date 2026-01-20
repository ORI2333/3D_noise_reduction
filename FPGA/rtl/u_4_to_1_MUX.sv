module u_4_to_1_MUX #(
    parameter                 D_WIDTH                     = 1     

)
(
    input                     [D_WIDTH - 1: 0]         i_port0                     ,
    input                     [D_WIDTH - 1: 0]         i_port1                     ,
    input                     [D_WIDTH - 1: 0]         i_port2                     ,
    input                     [D_WIDTH - 1: 0]         i_port3                     ,
    input                     [          1: 0]         sel                         ,
    output                    [D_WIDTH - 1: 0]         o_port_sel                  
);

    assign     o_port_sel    =      (sel == 2'b00) ? i_port0 
                                :   (sel == 2'b01) ? i_port1  
                                :   (sel == 2'b10) ? i_port2     
                                :                               i_port3                             ;
                                
endmodule