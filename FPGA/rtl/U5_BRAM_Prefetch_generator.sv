`timescale 1ns / 1ps 

module U5_BRAM_Prefetch_generator #(
    parameter       H_DISP = 640
)
(
    input                                       clk                         ,
    input                                       rst                         ,
    //---------------------------------------------------------------------------------------
    //                                                                                     
    //---------------------------------------------------------------------------------------
    input                                       prefetch                    ,
    input                                       prefetch_type               ,// 0 为init模式 1�?4行读取模�?
    input                     [  31: 0]         prefetch_addr               ,
    //---------------------------------------------------------------------------------------
    //                                                                                     
    //---------------------------------------------------------------------------------------
    output reg                                  o_ena_dma_rd_r              ,//! 本地读请�?
    output reg                [  31: 0]         o_addr_dma_rd               ,//! 本地读地�?
    output reg                [  31: 0]         o_lenth_dma_rd              ,//! 本地读长�?
    input                                       i_finish_dma_rd              //! 本地读完�?

);

    localparam                rd_idle                     = 0               ;
    localparam                rd_data                     = 1               ;

    reg                       [   0: 0]         r_state                     ;
    wire                      [  31: 0]         rd_lenth                    ;

    assign  rd_lenth              = (~prefetch_type)? H_DISP * 5 * 2 * 4 * 3
                                                    : H_DISP * 1 * 4 * 3    ;//init模式读取�?26行宏块数�?

    always @(posedge clk ) begin
        if (rst) begin
            r_state                     <=                  rd_idle         ;
        end
        else begin
            case (r_state)
                rd_idle: begin
                    if (prefetch) begin
                        r_state         <=                  rd_data         ;
                    end
                    else begin
                        r_state         <=                  rd_idle         ;
                    end
                end
                rd_data: begin
                    if (i_finish_dma_rd) begin
                        r_state         <=                  rd_idle         ;
                    end
                    else begin
                        r_state         <=                  rd_data         ;
                    end
                end
                default: begin
                    r_state             <=                  rd_idle         ;
                end
            endcase 
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            o_ena_dma_rd_r              <=                  1'b0            ;
            o_addr_dma_rd               <=                   'b0            ;
            o_lenth_dma_rd              <=                 32'b0            ;    
        end
        else begin
            if (prefetch) begin
                o_ena_dma_rd_r          <=                  1'b1            ;
                o_addr_dma_rd           <=                  prefetch_addr   ;
                o_lenth_dma_rd          <=                  rd_lenth        ;    
            end
            else begin
                o_ena_dma_rd_r          <=                  1'b0            ;
                o_addr_dma_rd           <=                   'b0            ;
                o_lenth_dma_rd          <=                   'b0            ;
            end
        end
    end

endmodule                                                          
