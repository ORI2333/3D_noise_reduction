module u_1_to_4_DEMUX #(
    parameter                 D_WIDTH                     = 1     
)
(
    output                    [D_WIDTH - 1: 0]         o_port0                     ,
    output                    [D_WIDTH - 1: 0]         o_port1                     ,
    output                    [D_WIDTH - 1: 0]         o_port2                     ,
    output                    [D_WIDTH - 1: 0]         o_port3                     ,
    input                     [          1: 0]         sel                         ,
    input                     [D_WIDTH - 1: 0]         i_port                       
);

    assign o_port0 = (sel == 2'b00) ? i_port : {D_WIDTH{1'b0}};
    
    assign o_port1 = (sel == 2'b01) ? i_port : {D_WIDTH{1'b0}};

    assign o_port2 = (sel == 2'b10) ? i_port : {D_WIDTH{1'b0}};

    assign o_port3 = (sel == 2'b11) ? i_port : {D_WIDTH{1'b0}};

endmodule