module U5_1_Read_InterConnect (
    input                                       i_rd_ena                    ,
    input                     [  14: 0]         i_rd_addr                   ,
    input                     [   1: 0]         i_rd_type                   ,
    input                                       i_MUX_reg                   ,

    output wire               [  14: 0]         o_MB0_addr                  ,
    output wire               [  14: 0]         o_MB1_addr                  ,
    output wire               [  12: 0]         o_DS0_addr                  ,
    output wire               [  12: 0]         o_DS1_addr                  ,
    output wire                                 o_MB0_ena                   ,
    output wire                                 o_MB1_ena                   ,
    output wire                                 o_DS0_ena                   ,
    output wire                                 o_DS1_ena                   ,

    input                     [  11: 0]         i_rd_data_f_MB0             ,
    input                     [  11: 0]         i_rd_data_f_MB1             ,
    input                     [  11: 0]         i_rd_data_f_DS0             ,
    input                     [  11: 0]         i_rd_data_f_DS1             ,

    output wire               [  11: 0]         o_rd_data_2_output           
);


    wire                      [  15: 0]         layer0_out0                 ;
    wire                      [  15: 0]         layer0_out1                 ;
    wire                      [  15: 0]         layer_1_0_out0              ;
    wire                      [  15: 0]         layer_1_0_out1              ;
    wire                      [  15: 0]         layer_1_0_out2              ;
    wire                      [  15: 0]         layer_1_0_out3              ;
    wire                      [  15: 0]         layer_1_1_out0              ;
    wire                      [  15: 0]         layer_1_1_out1              ;
    wire                      [  15: 0]         layer_2_0_out               ;
    wire                      [  15: 0]         layer_2_1_out               ;

    assign                              o_MB1_addr                  = layer_2_1_out[14:0];
    assign                              o_MB1_ena                   = layer_2_1_out[15];

    assign                              o_MB0_addr                  = layer_2_0_out[14:0];
    assign                              o_MB0_ena                   = layer_2_0_out[15];

    assign                              o_DS0_addr                  = layer_1_0_out0[12:0];
    assign                              o_DS0_ena                   = layer_1_0_out0[15];

    assign                              o_DS1_addr                  = layer_1_0_out1[12:0];
    assign                              o_DS1_ena                   = layer_1_0_out1[15];

u_1_to_2_DEMUX  #(
    .D_WIDTH                                   (16                         ) 
)
layer_0(
    .o_port0                                   (layer0_out0                ),
    .o_port1                                   (layer0_out1                ),
    .sel                                       (~(i_rd_type[1]^i_rd_type[0])),
    .i_port                                    ({i_rd_ena,i_rd_addr}       ) 
);



u_1_to_4_DEMUX #(
    .D_WIDTH                                   (16                         ) 
)layer_1_0(
    .o_port0                                   (layer_1_0_out0             ),
    .o_port1                                   (layer_1_0_out1             ),
    .o_port2                                   (layer_1_0_out2             ),
    .o_port3                                   (layer_1_0_out3             ),
    .sel                                       ({i_rd_type[1],~i_MUX_reg}  ),
    .i_port                                    (layer0_out0                ) 
);


u_1_to_2_DEMUX #(
    .D_WIDTH                                   (16                         ) 
)layer_1_1(
    .o_port0                                   (layer_1_1_out0             ),
    .o_port1                                   (layer_1_1_out1             ),
    .sel                                       (i_MUX_reg                  ),
    .i_port                                    (layer0_out1                ) 
);


u_2_to_1_MUX #(
    .D_WIDTH                                   (16                         ) 
)layer_2_0(
    .i_port0                                   (layer_1_0_out2             ),
    .i_port1                                   (layer_1_1_out0             ),
    .sel                                       (~(i_rd_type[1]^i_rd_type[0])),
    .o_port_sel                                (layer_2_0_out              ) 
);



u_2_to_1_MUX #(
    .D_WIDTH                                   (16                         ) 
)layer_2_1(
    .i_port0                                   (layer_1_0_out3             ),
    .i_port1                                   (layer_1_1_out1             ),
    .sel                                       (~(i_rd_type[1]^i_rd_type[0])),
    .o_port_sel                                (layer_2_1_out              ) 
);

//---------------------------------------------
// ����Ϊ��ַ��ʹ�ܴ��䣬����������������                                                                                    
//---------------------------------------------


    wire                      [  11: 0]         w_o_Proc_MB_data            ;
    wire                      [  11: 0]         w_o_Proc_DS_data            ;
    wire                      [  11: 0]         w_o_Matc_MB_data            ;
    wire                      [  11: 0]         w_o_Matc_DS_data            ;

    
u_2_to_1_MUX #(
    .D_WIDTH                                   (12                         ) 
)u_u_2_to_1_MUX_MB(
    .i_port0                                   (i_rd_data_f_MB0            ),
    .i_port1                                   (i_rd_data_f_MB1            ),
    .sel                                       (i_MUX_reg                  ),
    .o_port_sel                                (w_o_Proc_MB_data           ),
    .o_port_unsel                              (w_o_Matc_MB_data           ) 
);

u_2_to_1_MUX #(
    .D_WIDTH                                   (12                         ) 
)u_u_2_to_1_MUX_DS(
    .i_port0                                   (i_rd_data_f_DS0            ),
    .i_port1                                   (i_rd_data_f_DS1            ),
    .sel                                       (i_MUX_reg                  ),
    .o_port_sel                                (w_o_Proc_DS_data           ),
    .o_port_unsel                              (w_o_Matc_DS_data           ) 
);

u_4_to_1_MUX #(
    .D_WIDTH                                   (12                         ) 
)u_u_4_to_1_MUX(
    .i_port0                                   (w_o_Proc_MB_data           ),
    .i_port1                                   (w_o_Matc_DS_data           ),
    .i_port2                                   (w_o_Matc_MB_data           ),
    .i_port3                                   (w_o_Proc_DS_data           ),
    .sel                                       (i_rd_type                  ),
    .o_port_sel                                (o_rd_data_2_output         ) 
);





endmodule