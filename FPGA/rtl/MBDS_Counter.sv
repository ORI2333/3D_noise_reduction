module MBDS_Counter #(
    parameter                 H_DISP                      = 640   ,
    parameter                 V_DISP                      = 480   
)(
    input                                       clk                         ,
    input                                       rst                         ,

    input                                       MB_ena                      ,
    input                                       DS_ena                      ,

    output reg                [   8: 0]         MB_vcnt                     ,
    output reg                [   8: 0]         DS_vcnt                      
);

    reg                       [   8: 0]         MB_hcnt                     ;
    reg                       [   8: 0]         DS_hcnt                     ;

    always @(posedge clk ) begin
        if (~rst_n) begin
            MB_hcnt         <=          'b0                                 ;    
        end 
        else begin
            if (MB_ena) begin
                if (MB_hcnt == H_DISP/4 - 1) begin
                    MB_hcnt <=          'b0                                 ;
                end 
                else begin
                    MB_hcnt <=          MB_hcnt + 1                         ;
                end
            end 
            else begin
                MB_hcnt     <=          MB_hcnt                             ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            MB_vcnt         <=          'b0                                 ;
        end 
        else begin
            if (MB_ena && (MB_hcnt == H_DISP/4 - 1)) begin
                if (MB_vcnt == V_DISP/4 - 1) begin
                    MB_vcnt <=          'B0                                 ;
                end
                else begin
                    MB_vcnt <=          MB_vcnt + 1                         ;
                end
            end 
            else begin
                MB_vcnt     <=          MB_vcnt                             ;
            end
        end
    end

    always @(posedge clk ) begin
        if (~rst_n) begin
            DS_hcnt         <=          'b0                                 ;
        end
        else begin
            if (DS_ena) begin
                if (DS_hcnt == H_DISP/8 - 1) begin
                    DS_hcnt     <=          'b0                             ;
                end
                else begin
                    DS_hcnt     <=          DS_hcnt + 1                     ;
                end
            end
            else begin
                DS_hcnt     <=          DS_hcnt                             ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst) begin
            DS_vcnt         <=          'b0                                 ;
        end 
        else begin
            if (DS_ena && (DS_hcnt == H_DISP/8 - 1)) begin
                if (DS_vcnt == V_DISP/8 - 1) begin
                    DS_vcnt <=          'B0                                 ;
                end
                else begin
                    DS_vcnt <=          DS_vcnt + 1                         ;
                end
            end 
            else begin
                DS_vcnt     <=          DS_vcnt                             ;
            end
        end
    end


endmodule