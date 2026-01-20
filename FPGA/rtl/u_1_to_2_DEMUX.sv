module u_1_to_2_DEMUX #(
    parameter                 D_WIDTH                     = 1     
)
(
    output                    [D_WIDTH - 1: 0]         o_port0                     ,
    output                    [D_WIDTH - 1: 0]         o_port1                     ,
    input                     [          0: 0]         sel                         ,
    input                     [D_WIDTH - 1: 0]         i_port                       
);

    assign o_port0 = (~sel) ? i_port : {D_WIDTH{1'b0}};
    
    assign o_port1 = ( sel) ? i_port : {D_WIDTH{1'b0}};

endmodule