`timescale 1ns / 1ps 




module U2_MBDS_8CH_Subsys #(
    parameter                 CHANNEL_NUM                 = 8     ,
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       R_ena                       ,
    input                                       G_ena                       ,
    input                                       B_ena                       ,

    
    input                                       R_data_valid                ,
    input                     [   7: 0]         R_data_in    [7:0]          ,
    input                                       G_data_valid                ,
    input                     [   7: 0]         G_data_in    [7:0]          ,
    input                                       B_data_valid                ,
    input                     [   7: 0]         B_data_in    [7:0]          ,

    
    
    
    output wire               [  11: 0]         R_MB_dout    [1:0]          ,           
    output wire                                 R_MB_ena                    ,
    output wire               [  11: 0]         B_MB_dout    [1:0]          ,           
    output wire                                 B_MB_ena                    ,
    output wire               [  11: 0]         G_MB_dout    [1:0]          ,           
    output wire                                 G_MB_ena                    ,
    
    
    
    output wire               [  11: 0]         R_Sub_dout                  ,
    output wire                                 R_Sub_ena                   ,
    output wire               [  11: 0]         G_Sub_dout                  ,
    output wire                                 G_Sub_ena                   ,
    output wire               [  11: 0]         B_Sub_dout                  ,
    output wire                                 B_Sub_ena                   ,

    
    
    

    output wire                                 finish_flag                 ,
    input                                       flag_clr                     
);


    reg                      finish_r                         ;
    reg                      finish_g                         ;
    reg                      finish_b                         ;

    wire                     R_finish_flag                    ;
    wire                     G_finish_flag                    ;
    wire                     B_finish_flag                    ;

U0_SinglePulse u_U0_SinglePulse(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .pos_dir                                   (finish_r & finish_g & finish_b),
    .pos_pulse                                 (finish_flag                  ) 
);




    always @(posedge clk ) 
    begin
        if (rst | flag_clr) begin
            finish_r            <=              1'b0                        ;
            finish_g            <=              1'b0                        ;
            finish_b            <=              1'b0                        ;
        end else begin
            if (R_finish_flag) begin
                finish_r        <=              1'b1                        ;
            end else begin
                finish_r        <=              finish_r                    ;    
            end
            
            if (G_finish_flag) begin
                finish_g        <=              1'b1                        ;

            end else begin
                finish_g        <=              finish_g                    ;    
            end
            
            if (B_finish_flag) begin
                finish_b        <=              1'b1                        ;
            end else begin
                finish_b        <=              finish_b                    ;    
            end
        end
    end

U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
 u_U2_MBDS_8CH_R(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (R_ena                      ),
    .data_valid                                (R_data_valid               ),
    .data_in                                   (R_data_in                  ),
    .MB_dout                                   (R_MB_dout                  ),
    .MB_ena                                    (R_MB_ena                   ),
    .Sub_dout                                  (R_Sub_dout                 ),
    .Sub_ena                                   (R_Sub_ena                  ),
    .finish_flag                               (R_finish_flag              ),
    .flag_clr                                  (flag_clr                 ) 
);


U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
u_U2_MBDS_8CH_G(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (G_ena                      ),
    .data_valid                                (G_data_valid               ),
    .data_in                                   (G_data_in                  ),
    .MB_dout                                   (G_MB_dout                  ),
    .MB_ena                                    (G_MB_ena                   ),
    .Sub_dout                                  (G_Sub_dout                 ),
    .Sub_ena                                   (G_Sub_ena                  ),
    .finish_flag                               (G_finish_flag              ),
    .flag_clr                                  (flag_clr                 ) 
);


U2_MBDS_8CH#(
    .CHANNEL_NUM                               (CHANNEL_NUM                ),
    .H_DISP                                    (H_DISP                     ),
    .V_DISP                                    (V_DISP                     ) 
)
u_U2_MBDS_8CH_B(
    .clk                                       (clk                        ),
    .rst                                       (rst                        ),
    .ena                                       (B_ena                      ),
    .data_valid                                (B_data_valid               ),
    .data_in                                   (B_data_in                  ),
    .MB_dout                                   (B_MB_dout                  ),
    .MB_ena                                    (B_MB_ena                   ),
    .Sub_dout                                  (B_Sub_dout                 ),
    .Sub_ena                                   (B_Sub_ena                  ),
    .finish_flag                               (B_finish_flag              ),
    .flag_clr                                  (flag_clr                 ) 
);


endmodule                                                          
