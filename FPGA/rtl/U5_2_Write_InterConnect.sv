module U5_2_Write_InterConnect(
    input                                       i_MUX_reg                   ,

    input                                       i_wr_MB_ena                 ,
    input                     [  14: 0]         i_wr_MB_addr                ,
    input                     [  11: 0]         i_wr_MB_data    [1:0]       ,

    input                                       i_wr_DS_ena                 ,
    input                     [  12: 0]         i_wr_DS_addr                ,
    input                     [  11: 0]         i_wr_DS_data                ,

    output wire                                 o_wr_MB0_ena                ,
    output wire               [  14: 0]         o_wr_MB0_addr               ,
    output wire               [  11: 0]         o_wr_MB0_data   [1:0]       ,

    output wire                                 o_wr_DS0_ena                ,
    output wire               [  12: 0]         o_wr_DS0_addr               ,
    output wire               [  11: 0]         o_wr_DS0_data               ,

    output wire                                 o_wr_MB1_ena                ,
    output wire               [  14: 0]         o_wr_MB1_addr               ,
    output wire               [  11: 0]         o_wr_MB1_data   [1:0]       ,

    output wire                                 o_wr_DS1_ena                ,
    output wire               [  12: 0]         o_wr_DS1_addr               ,
    output wire               [  11: 0]         o_wr_DS1_data                

);

u_1_to_2_DEMUX  #(
    .D_WIDTH                                   (1                          ) 
)
u_u_1_to_2_DEMUX_MB_Ena(
    .o_port0                                   (o_wr_MB0_ena               ),
    .o_port1                                   (o_wr_MB1_ena               ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_MB_ena                ) 
);

u_1_to_2_DEMUX #(
    .D_WIDTH                                   (15                         ) 
)
u_u_1_to_2_DEMUX_MB_Addr(
    .o_port0                                   (o_wr_MB0_addr              ),
    .o_port1                                   (o_wr_MB1_addr              ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_MB_addr               ) 
);

u_1_to_2_DEMUX #(
    .D_WIDTH                                   (12                         )
)
u_u_1_to_2_DEMUX_MB_Data0(
    .o_port0                                   (o_wr_MB0_data[0]           ),
    .o_port1                                   (o_wr_MB1_data[0]           ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_MB_data[0]            ) 
);

u_1_to_2_DEMUX #(
    .D_WIDTH                                   (12                         ) 
)
u_u_1_to_2_DEMUX_MB_Data1(
    .o_port0                                   (o_wr_MB0_data[1]           ),
    .o_port1                                   (o_wr_MB1_data[1]           ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_MB_data[1]            ) 
);

//---------------------------------------------------------
//                                                         
//---------------------------------------------------------


u_1_to_2_DEMUX #(
    .D_WIDTH                                   (1                          ) 
)
u_u_1_to_2_DEMUX_DS_Ena(
    .o_port0                                   (o_wr_DS0_ena               ),
    .o_port1                                   (o_wr_DS1_ena               ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_DS_ena                ) 
);

u_1_to_2_DEMUX #(
    .D_WIDTH                                   (13                         ) 
)
u_u_1_to_2_DEMUX_DS_Addr(
    .o_port0                                   (o_wr_DS0_addr              ),
    .o_port1                                   (o_wr_DS1_addr              ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_DS_addr               ) 
);

u_1_to_2_DEMUX #(
    .D_WIDTH                                   (12                          ) 
)
u_u_1_to_2_DEMUX_DS_Data(
    .o_port0                                   (o_wr_DS0_data              ),
    .o_port1                                   (o_wr_DS1_data              ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (i_wr_DS_data               ) 
);

endmodule                                                          
