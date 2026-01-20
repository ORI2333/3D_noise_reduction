// { signal: [
//     { name: "clk          " , wave:"P.....|.............|......." },
//     { name: "i_wr_MUX_reg " , wave:"H.................|L........" },
//     { name: "i_wr_MB_ena  " , wave:"l.h.|..l....h.|..l..h.|..l.." },
//     { name: "i_wr_MB_addr " , wave:"x.34|78x....34|78x..34|78x.." ,data: ["addr0","addr1","addr2","addr3","addr4","addr5","addr6","addr7","addr8","addr9","addra","addrb"]},
//     { name: "i_wr_MB_data " , wave:"x.34|78x....34|78x..34|78x.." ,data: ["din0","din1","din2","din3","din4","din5","din6","din7","din8","din9","dina","dinb"]},
//     { name: "i_wr_DS_ena  " , wave:"l.h|.l....h|.l........h|.l.." },
//     { name: "i_wr_DS_addr " , wave:"x.3|8x....3|8x........3|8x.." ,data: ["addr0","addr1","addr2","addr3","addr4","addr5"]},
//     { name: "i_wr_DS_data " , wave:"x.3|8x....3|8x........3|8x.." ,data: ["din0","din1","din2","din3","din4","din5"]},
//     { name: "i_rd_MUX_reg " , wave:"3.................|........." ,data: ["same_as_i_wr_MUX_reg"]},
//     { name: "i_rd_ena     " , wave:"l..h.l...|.h...l............" },
//     { name: "i_rd_type    " , wave:"x..3.x...|.345x............." ,data: ["type0","type1","type2","type3"]},
//     { name: "i_rd_addr    " , wave:"x..4.x...|.456x............." ,data: ["addr0","addr1","addr2","addr3"]},
//     { name: "o_rd_data    " , wave:"x....5x..|...345x..........." ,data: ["dout0","dout1","dout2","dout3"]}
//         ],
//   head: {
//         text : 'U5_BRAM_Controller',
//         every:  1
//         },
//   config: { hscale: 1 }
// }






module U5_BRAM_Controller (

input                                       clk                         ,//时钟

//-----------------------------------
// Write_Interface                       
//-----------------------------------

input                                       i_wr_MUX_reg                ,//!控制内部互联的模�??

input                                       i_wr_MB_ena                 ,//!输入宏块数据有效
input                     [  14: 0]         i_wr_MB_addr                ,//!输入宏块BRAM地址
input                     [  11: 0]         i_wr_MB_data [1:0]          ,//!输入宏块数据

input                                       i_wr_DS_ena                 ,//!输入下采样块数据有效
input                     [  12: 0]         i_wr_DS_addr                ,//!输入下采样块BRAM地址
input                     [  11: 0]         i_wr_DS_data                ,//!输入下采样块数据

//-----------------------------------
// Read_Interface                       
//-----------------------------------

input                                       i_rd_MUX_reg                ,//!控制读取内部互联
input                     [   1: 0]         i_rd_type    [7:0]          ,//!辅助读取内部互联
input                                       i_rd_ena     [7:0]          ,//!读取使能
input                     [  14: 0]         i_rd_addr    [7:0]          ,//!读取BRAM地址

output                    [  11: 0]         o_rd_data    [7:0]           //!读取的数�??


);

    wire                      [  11: 0]         i_w_MB_dout0  [7:0]         ;
    wire                      [  11: 0]         i_w_MB_dout1  [7:0]         ;
    wire                      [  11: 0]         i_w_DS_dout0  [7:0]         ;
    wire                      [  11: 0]         i_w_DS_dout1  [7:0]         ;

    wire                      [   0: 0]         o_wr_MB0_ena                ;
    wire                      [   0: 0]         o_wr_DS0_ena                ;
    wire                      [  14: 0]         o_wr_MB0_addr               ;
    wire                      [  12: 0]         o_wr_DS0_addr               ;
    wire                      [  11: 0]         o_wr_MB0_data[1:0]          ;
    wire                      [  11: 0]         o_wr_DS0_data               ;
    
    wire                      [   0: 0]         o_wr_MB1_ena                ;
    wire                      [   0: 0]         o_wr_DS1_ena                ;
    wire                      [  14: 0]         o_wr_MB1_addr               ;
    wire                      [  12: 0]         o_wr_DS1_addr               ;
    wire                      [  11: 0]         o_wr_MB1_data[1:0]          ;
    wire                      [  11: 0]         o_wr_DS1_data               ;

    wire                                        o_MB0_ena    [7:0]          ;
    wire                      [  14: 0]         o_MB0_addr   [7:0]          ;
    wire                                        o_DS0_ena    [7:0]          ;
    wire                      [  12: 0]         o_DS0_addr   [7:0]          ;
    wire                                        o_MB1_ena    [7:0]          ;
    wire                      [  14: 0]         o_MB1_addr   [7:0]          ;
    wire                                        o_DS1_ena    [7:0]          ;
    wire                      [  12: 0]         o_DS1_addr   [7:0]          ;

    genvar i;

    generate

        for (i = 0;i < 8 ;i =i + 1 ) begin
            
            U5_1_Read_InterConnect u_U5_1_Read_InterConnect(

            .i_rd_type                                 (i_rd_type[i]               ),
            .i_MUX_reg                                 (i_rd_MUX_reg               ),
            .i_rd_ena                                  (i_rd_ena[i]                ),
            .i_rd_addr                                 (i_rd_addr[i]               ),

            .o_rd_data_2_output                        (o_rd_data[i]               ),

            .o_MB0_addr                                (o_MB0_addr[i]              ),
            .o_MB1_addr                                (o_MB1_addr[i]              ),
            .o_DS0_addr                                (o_DS0_addr[i]              ),
            .o_DS1_addr                                (o_DS1_addr[i]              ),

            .o_MB0_ena                                 (o_MB0_ena  [i]             ),
            .o_MB1_ena                                 (o_MB1_ena  [i]             ),
            .o_DS0_ena                                 (o_DS0_ena  [i]             ),
            .o_DS1_ena                                 (o_DS1_ena  [i]             ),

            .i_rd_data_f_MB0                           (i_w_MB_dout0[i]            ),
            .i_rd_data_f_MB1                           (i_w_MB_dout1[i]            ),
            .i_rd_data_f_DS0                           (i_w_DS_dout0[i]            ),
            .i_rd_data_f_DS1                           (i_w_DS_dout1[i]            ) 
        
            );

        end

    endgenerate




U5_2_Write_InterConnect u_U5_2_Write_InterConnect (

    .i_MUX_reg                                 (i_wr_MUX_reg               ),

    .i_wr_MB_ena                               (i_wr_MB_ena                ),
    .i_wr_MB_addr                              (i_wr_MB_addr               ),
    .i_wr_MB_data                              (i_wr_MB_data[1:0]          ),
    .i_wr_DS_ena                               (i_wr_DS_ena                ),
    .i_wr_DS_addr                              (i_wr_DS_addr               ),
    .i_wr_DS_data                              (i_wr_DS_data               ),

    .o_wr_MB0_ena                              (o_wr_MB0_ena               ),
    .o_wr_DS0_ena                              (o_wr_DS0_ena               ),
    .o_wr_MB0_addr                             (o_wr_MB0_addr              ),
    .o_wr_DS0_addr                             (o_wr_DS0_addr              ),
    .o_wr_MB0_data                             (o_wr_MB0_data[1:0]         ),
    .o_wr_DS0_data                             (o_wr_DS0_data              ),

    .o_wr_MB1_ena                              (o_wr_MB1_ena               ),
    .o_wr_DS1_ena                              (o_wr_DS1_ena               ),
    .o_wr_MB1_addr                             (o_wr_MB1_addr              ),
    .o_wr_DS1_addr                             (o_wr_DS1_addr              ),
    .o_wr_MB1_data                             (o_wr_MB1_data[1:0]         ),
    .o_wr_DS1_data                             (o_wr_DS1_data              )
);

//2 write port and 8 read port

U5_3_BRAM_28port#(
    .ADDR_WIDTH                                (12                         ),
    .DATA_WIDTH                                (12                         ),
    .DEPTH                                     (2880                       ) 
)
u_U5_3_BRAM_28port_MB0(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .we1                                       (o_wr_MB0_ena               ),
    .we2                                       (o_wr_MB0_ena               ),

    .wr_addr1                                  (o_wr_MB0_addr              ),
    .wr_addr2                                  (o_wr_MB0_addr + 1          ),
    .wr_data1                                  (o_wr_MB0_data[0]           ),
    .wr_data2                                  (o_wr_MB0_data[1]           ),
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------
    .re1                                       (o_MB0_ena[0]               ),
    .re2                                       (o_MB0_ena[1]               ),
    .re3                                       (o_MB0_ena[2]               ),
    .re4                                       (o_MB0_ena[3]               ),
    .re5                                       (o_MB0_ena[4]               ),
    .re6                                       (o_MB0_ena[5]               ),
    .re7                                       (o_MB0_ena[6]               ),
    .re8                                       (o_MB0_ena[7]               ),

    .rd_addr1                                  (o_MB0_addr[0]              ),
    .rd_addr2                                  (o_MB0_addr[1]              ),
    .rd_addr3                                  (o_MB0_addr[2]              ),
    .rd_addr4                                  (o_MB0_addr[3]              ),
    .rd_addr5                                  (o_MB0_addr[4]              ),
    .rd_addr6                                  (o_MB0_addr[5]              ),
    .rd_addr7                                  (o_MB0_addr[6]              ),
    .rd_addr8                                  (o_MB0_addr[7]              ),

    .rd_data1                                  (i_w_MB_dout0[0]            ),
    .rd_data2                                  (i_w_MB_dout0[1]            ),
    .rd_data3                                  (i_w_MB_dout0[2]            ),
    .rd_data4                                  (i_w_MB_dout0[3]            ),
    .rd_data5                                  (i_w_MB_dout0[4]            ),
    .rd_data6                                  (i_w_MB_dout0[5]            ),
    .rd_data7                                  (i_w_MB_dout0[6]            ),
    .rd_data8                                  (i_w_MB_dout0[7]            ) 
);



U5_3_BRAM_28port#(
    .ADDR_WIDTH                                (12                         ),
    .DATA_WIDTH                                (12                         ),
    .DEPTH                                     (2880                       ) 
)
u_U5_3_BRAM_28port_MB1(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .we1                                       (o_wr_MB1_ena               ),
    .we2                                       (o_wr_MB1_ena               ),

    .wr_addr1                                  (o_wr_MB1_addr              ),
    .wr_addr2                                  (o_wr_MB1_addr + 1          ),
    .wr_data1                                  (o_wr_MB1_data[0]           ),
    .wr_data2                                  (o_wr_MB1_data[1]           ),
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------
    .re1                                       (o_MB1_ena[0]               ),
    .re2                                       (o_MB1_ena[1]               ),
    .re3                                       (o_MB1_ena[2]               ),
    .re4                                       (o_MB1_ena[3]               ),
    .re5                                       (o_MB1_ena[4]               ),
    .re6                                       (o_MB1_ena[5]               ),
    .re7                                       (o_MB1_ena[6]               ),
    .re8                                       (o_MB1_ena[7]               ),

    .rd_addr1                                  (o_MB1_addr[0]              ),
    .rd_addr2                                  (o_MB1_addr[1]              ),
    .rd_addr3                                  (o_MB1_addr[2]              ),
    .rd_addr4                                  (o_MB1_addr[3]              ),
    .rd_addr5                                  (o_MB1_addr[4]              ),
    .rd_addr6                                  (o_MB1_addr[5]              ),
    .rd_addr7                                  (o_MB1_addr[6]              ),
    .rd_addr8                                  (o_MB1_addr[7]              ),

    .rd_data1                                  (i_w_MB_dout1[0]            ),
    .rd_data2                                  (i_w_MB_dout1[1]            ),
    .rd_data3                                  (i_w_MB_dout1[2]            ),
    .rd_data4                                  (i_w_MB_dout1[3]            ),
    .rd_data5                                  (i_w_MB_dout1[4]            ),
    .rd_data6                                  (i_w_MB_dout1[5]            ),
    .rd_data7                                  (i_w_MB_dout1[6]            ),
    .rd_data8                                  (i_w_MB_dout1[7]            ) 
);


//---------------------------------------------------------------------------------------
////1 write port and 8 read port
//---------------------------------------------------------------------------------------


U5_3_BRAM_28port#(
    .ADDR_WIDTH                                (10                         ),
    .DATA_WIDTH                                (12                         ),
    .DEPTH                                     (720                        ) 
)
u_U5_3_BRAM_18port_DS0(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .we1                                       (o_wr_DS0_ena               ),

    .wr_addr1                                  (o_wr_DS0_addr              ),
    .wr_data1                                  (o_wr_DS0_data              ),
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------
    .re1                                       (o_DS0_ena[0]               ),
    .re2                                       (o_DS0_ena[1]               ),
    .re3                                       (o_DS0_ena[2]               ),
    .re4                                       (o_DS0_ena[3]               ),
    .re5                                       (o_DS0_ena[4]               ),
    .re6                                       (o_DS0_ena[5]               ),
    .re7                                       (o_DS0_ena[6]               ),
    .re8                                       (o_DS0_ena[7]               ),

    .rd_addr1                                  (o_DS0_addr[0]              ),
    .rd_addr2                                  (o_DS0_addr[1]              ),
    .rd_addr3                                  (o_DS0_addr[2]              ),
    .rd_addr4                                  (o_DS0_addr[3]              ),
    .rd_addr5                                  (o_DS0_addr[4]              ),
    .rd_addr6                                  (o_DS0_addr[5]              ),
    .rd_addr7                                  (o_DS0_addr[6]              ),
    .rd_addr8                                  (o_DS0_addr[7]              ),

    .rd_data1                                  (i_w_DS_dout0[0]            ),
    .rd_data2                                  (i_w_DS_dout0[1]            ),
    .rd_data3                                  (i_w_DS_dout0[2]            ),
    .rd_data4                                  (i_w_DS_dout0[3]            ),
    .rd_data5                                  (i_w_DS_dout0[4]            ),
    .rd_data6                                  (i_w_DS_dout0[5]            ),
    .rd_data7                                  (i_w_DS_dout0[6]            ),
    .rd_data8                                  (i_w_DS_dout0[7]            ) 
);


U5_3_BRAM_28port#(
    .ADDR_WIDTH                                (10                         ),
    .DATA_WIDTH                                (12                         ),
    .DEPTH                                     (720                        ) 
)
u_U5_3_BRAM_18port_DS1(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),

    .we1                                       (o_wr_DS1_ena               ),

    .wr_addr1                                  (o_wr_DS1_addr              ),
    .wr_data1                                  (o_wr_DS1_data              ),
//---------------------------------------------------------------------------------------
//                                                                                     
//---------------------------------------------------------------------------------------
    .re1                                       (o_DS1_ena[0]               ),
    .re2                                       (o_DS1_ena[1]               ),
    .re3                                       (o_DS1_ena[2]               ),
    .re4                                       (o_DS1_ena[3]               ),
    .re5                                       (o_DS1_ena[4]               ),
    .re6                                       (o_DS1_ena[5]               ),
    .re7                                       (o_DS1_ena[6]               ),
    .re8                                       (o_DS1_ena[7]               ),

    .rd_addr1                                  (o_DS1_addr[0]              ),
    .rd_addr2                                  (o_DS1_addr[1]              ),
    .rd_addr3                                  (o_DS1_addr[2]              ),
    .rd_addr4                                  (o_DS1_addr[3]              ),
    .rd_addr5                                  (o_DS1_addr[4]              ),
    .rd_addr6                                  (o_DS1_addr[5]              ),
    .rd_addr7                                  (o_DS1_addr[6]              ),
    .rd_addr8                                  (o_DS1_addr[7]              ),

    .rd_data1                                  (i_w_DS_dout1[0]            ),
    .rd_data2                                  (i_w_DS_dout1[1]            ),
    .rd_data3                                  (i_w_DS_dout1[2]            ),
    .rd_data4                                  (i_w_DS_dout1[3]            ),
    .rd_data5                                  (i_w_DS_dout1[4]            ),
    .rd_data6                                  (i_w_DS_dout1[5]            ),
    .rd_data7                                  (i_w_DS_dout1[6]            ),
    .rd_data8                                  (i_w_DS_dout1[7]            ) 
);

endmodule