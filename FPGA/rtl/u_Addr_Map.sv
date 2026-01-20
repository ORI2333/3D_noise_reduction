`timescale 1ns / 1ps 

module u_Addr_Map # (
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   ,
    parameter                 CHANNEL_NUM                 = 8   
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       rd_ena   [CHANNEL_NUM - 1:0],
    input                     [   1: 0]         rd_type  [CHANNEL_NUM - 1:0],
    input                     [  15: 0]         rd_site  [CHANNEL_NUM - 1:0],
    output reg                [   1: 0]         rd_type_d[CHANNEL_NUM - 1:0],
    output reg                                  rd_ena_d [CHANNEL_NUM - 1:0],
    output wire               [  14: 0]         rd_addr  [CHANNEL_NUM - 1:0] 
);

    reg                       [   7: 0]         rd_site_x_mapped [CHANNEL_NUM - 1:0];
    reg                       [   7: 0]         rd_site_y_mapped [CHANNEL_NUM - 1:0];

    genvar  i;
    generate
        for (i = 0; i < 8;i = i + 1 ) begin
           assign  rd_addr[i] = (rd_type[i] == 2'b10) ? rd_site_x_mapped[i] + rd_site_y_mapped[i] * (H_DISP / 4)
                                               : rd_site_x_mapped[i] + rd_site_y_mapped[i] * (H_DISP / 8);


            always @(posedge clk ) begin
                if (rst) begin
                    rd_site_x_mapped[i]            <=      'b0                      ;
                end 
                else begin
                    if (rd_ena[i]) begin
                        rd_site_x_mapped[i]        <=      rd_site[i][7:0]          ;
                    end 
                    else begin
                        rd_site_x_mapped[i]        <=      rd_site_x_mapped[i]      ;
                    end
                end
            end
            
            
            always @(posedge clk ) begin
                if (rst) begin
                    rd_site_y_mapped[i]            <=      'b0                      ;
                end
                else begin
                    if (rd_ena[i]) begin
                        if (rd_type[i] == 2'b10) begin
                            rd_site_y_mapped[i]    <=      rd_site[i][15:8] % 18    ;
                        end
                        else begin
                            rd_site_y_mapped[i]    <=      rd_site[i][15:8] %  9    ;
                        end
                    end
                    else begin
                        rd_site_y_mapped[i]        <=      rd_site_y_mapped[i]      ;
                    end
                end
            end
                        
            always @(posedge clk ) begin
                if (rst) begin
                    rd_ena_d[i]                    <=      1'b0                     ;
                end
                else begin
                    rd_ena_d[i]                    <=      rd_ena[i]                ;
                end
            end
            
            always @(posedge clk ) begin
                if (rst) begin
                    rd_type_d[i]                   <=      2'b0                     ;
                end 
                else begin
                    rd_type_d[i]                   <=      rd_type[i]               ;
                end
            end
        
        end
    endgenerate





endmodule                                                          
