module u_2_to_1_MUX #(
    parameter                 D_WIDTH                     = 1     

)
(
    input                     [D_WIDTH - 1: 0]         i_port0                     ,
    input                     [D_WIDTH - 1: 0]         i_port1                     ,
    input                     [          0: 0]         sel                         ,
    output                    [D_WIDTH - 1: 0]         o_port_sel                  ,
    output                    [D_WIDTH - 1: 0]         o_port_unsel                 
);

    assign     o_port_sel    = (sel) ? i_port1 : i_port0                           ;

    assign     o_port_unsel  = (sel) ? i_port0 : i_port1                           ;


endmodule