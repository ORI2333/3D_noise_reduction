`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/24 16:07:42
// Design Name: 
// Module Name: U7_1_0_1_1_Max_reg_SAD_Vector
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module U4_2_Max_reg_SAD_Vector(
    input                               clk                         ,
    input                               rst                         ,

    input                               start                       ,
    input              [   1: 0]        compare_type                ,

    input              [  11: 0]        base_blk                    ,
    input              [  11: 0]        match_blk_0                 ,
    input              [  11: 0]        match_blk_1                 ,
    input              [  11: 0]        match_blk_2                 ,
    input              [  11: 0]        match_blk_3                 ,
    input              [  11: 0]        match_blk_4                 ,
    input              [  11: 0]        match_blk_5                 ,
    input              [  11: 0]        match_blk_6                 ,
    input              [  11: 0]        match_blk_7                 ,
    input              [  11: 0]        match_blk_8                 ,

    input                               match_blk_ena_0             ,
    input                               match_blk_ena_1             ,
    input                               match_blk_ena_2             ,
    input                               match_blk_ena_3             ,
    input                               match_blk_ena_4             ,
    input                               match_blk_ena_5             ,
    input                               match_blk_ena_6             ,
    input                               match_blk_ena_7             ,
    input                               match_blk_ena_8             ,

    output reg                          finish_flag                 ,
    input                               flag_clr                    ,
    output reg         [   3: 0]        minimum_id                  ,
    output  reg signed [   2: 0]        vector_row                  ,
    output  reg signed [   2: 0]        vector_col                  ,
    output reg         [  11: 0]        SAD                         
    );

    reg                [   1: 0]        matching_type               ;
    reg                [  11: 0]        base_blk_r                  ;
    reg                [  11: 0]        match_blk_r          [8:0]  ;
    reg                [   8: 0]        match_blk_ena_r             ;
    reg                [  11: 0]        subtract_r           [8:0]  ;

    reg                                 finish_flag1                ;
    reg                                 finish_flag2                ;
    reg                                 finish_flag3_1              ;
    reg                                 finish_flag3_2              ;
    reg                                 finish_flag3_3              ;
    reg                                 finish_flag3_4              ;

    reg                [  15: 0]        compare_2x1          [3:0]  ;
    reg                [  15: 0]        compare_2x1_stage2   [1:0]  ;
    reg                [  15: 0]        compare_2x1_stage3          ;
    reg                [  15: 0]        final_compare               ;


    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            finish_flag                     <=       'b0                            ;
            finish_flag1                    <=       'b0                            ;
            finish_flag2                    <=       'b0                            ;
            finish_flag3_1                  <=       'b0                            ;
            finish_flag3_2                  <=       'b0                            ;  
            finish_flag3_3                  <=       'b0                            ;
            finish_flag3_4                  <=       'b0                            ;
        end
        else begin
            finish_flag                     <=      finish_flag3_4                  ;
            finish_flag3_4                  <=      finish_flag3_3                  ;
            finish_flag3_3                  <=      finish_flag3_2                  ;
            finish_flag3_2                  <=      finish_flag3_1                  ;
            finish_flag3_1                  <=      finish_flag2                    ;
            finish_flag2                    <=      finish_flag1                    ;
            finish_flag1                    <=      start                           ;
        end
    end



    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            matching_type                   <=      'b0                             ;
            base_blk_r                      <=      'b0                             ;
            match_blk_ena_r                 <=      'b0                             ;
            match_blk_r[0]                  <=      'b0                             ;
            match_blk_r[1]                  <=      'b0                             ;
            match_blk_r[2]                  <=      'b0                             ;
            match_blk_r[3]                  <=      'b0                             ;
            match_blk_r[4]                  <=      'b0                             ;
            match_blk_r[5]                  <=      'b0                             ;
            match_blk_r[6]                  <=      'b0                             ;
            match_blk_r[7]                  <=      'b0                             ;
            match_blk_r[8]                  <=      'b0                             ;
        end 
        else begin
            if (start) begin
                matching_type               <=      compare_type                    ;
                base_blk_r                  <=      base_blk                        ;

                match_blk_ena_r[0]          <=      match_blk_ena_0                 ;
                match_blk_ena_r[1]          <=      match_blk_ena_1                 ;
                match_blk_ena_r[2]          <=      match_blk_ena_2                 ;
                match_blk_ena_r[3]          <=      match_blk_ena_3                 ;
                match_blk_ena_r[4]          <=      match_blk_ena_4                 ;
                match_blk_ena_r[5]          <=      match_blk_ena_5                 ;
                match_blk_ena_r[6]          <=      match_blk_ena_6                 ;
                match_blk_ena_r[7]          <=      match_blk_ena_7                 ;
                match_blk_ena_r[8]          <=      match_blk_ena_8                 ;

                match_blk_r[0]              <=      match_blk_0                     ;
                match_blk_r[1]              <=      match_blk_1                     ;
                match_blk_r[2]              <=      match_blk_2                     ;
                match_blk_r[3]              <=      match_blk_3                     ;
                match_blk_r[4]              <=      match_blk_4                     ;
                match_blk_r[5]              <=      match_blk_5                     ;
                match_blk_r[6]              <=      match_blk_6                     ;
                match_blk_r[7]              <=      match_blk_7                     ;
                match_blk_r[8]              <=      match_blk_8                     ;
            end 
            else begin
                matching_type               <=      matching_type                   ;
                base_blk_r                  <=      base_blk_r                      ;
                match_blk_ena_r[0]          <=      match_blk_ena_r[0]              ;
                match_blk_ena_r[1]          <=      match_blk_ena_r[1]              ;
                match_blk_ena_r[2]          <=      match_blk_ena_r[2]              ;
                match_blk_ena_r[3]          <=      match_blk_ena_r[3]              ;
                match_blk_ena_r[4]          <=      match_blk_ena_r[4]              ;
                match_blk_ena_r[5]          <=      match_blk_ena_r[5]              ;
                match_blk_ena_r[6]          <=      match_blk_ena_r[6]              ;
                match_blk_ena_r[7]          <=      match_blk_ena_r[7]              ;
                match_blk_ena_r[8]          <=      match_blk_ena_r[8]              ;
                match_blk_r[0]              <=      match_blk_r[0]                  ;
                match_blk_r[1]              <=      match_blk_r[1]                  ;
                match_blk_r[2]              <=      match_blk_r[2]                  ;
                match_blk_r[3]              <=      match_blk_r[3]                  ;
                match_blk_r[4]              <=      match_blk_r[4]                  ;
                match_blk_r[5]              <=      match_blk_r[5]                  ;
                match_blk_r[6]              <=      match_blk_r[6]                  ;
                match_blk_r[7]              <=      match_blk_r[7]                  ;
                match_blk_r[8]              <=      match_blk_r[8]                  ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[0]                   <=       'b0                            ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[0]) begin
                    if (base_blk_r > match_blk_r[0]) begin
                        subtract_r[0]       <=      base_blk_r - match_blk_r[0]     ;
                    end
                    else begin
                        subtract_r[0]       <=      match_blk_r[0] - base_blk_r     ;
                    end
                end
                else begin
                    subtract_r [0]          <=      12'hfff                        ;
                end
            end 
            else begin
                subtract_r[0]               <=      subtract_r[0]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[1]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[1]) begin
                    if (base_blk_r > match_blk_r[1]) begin
                        subtract_r[1]       <=      base_blk_r - match_blk_r[1]     ;
                    end 
                    else begin
                        subtract_r[1]       <=      match_blk_r[1] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [1]          <=      12'hfff                           ;
                end
            end 
            else begin
                subtract_r[1]               <=      subtract_r[1]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[2]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[2]) begin
                    if (base_blk_r > match_blk_r[2]) begin
                        subtract_r[2]       <=      base_blk_r - match_blk_r[2]     ;
                    end 
                    else begin
                        subtract_r[2]       <=      match_blk_r[2] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [2]          <=      12'hfff                           ;
                end
            end 
            else begin
                subtract_r[2]               <=      subtract_r[2]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[3]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[3]) begin
                    if (base_blk_r > match_blk_r[3]) begin
                        subtract_r[3]       <=      base_blk_r - match_blk_r[3]     ;
                    end 
                    else begin
                        subtract_r[3]       <=      match_blk_r[3] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [3]          <=      12'hfff                           ;
                end
            end 
            else begin
                subtract_r[3]               <=      subtract_r[3]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[4]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[4]) begin
                    if (base_blk_r > match_blk_r[4]) begin
                        subtract_r[4]       <=      base_blk_r - match_blk_r[4]     ;
                    end 
                    else begin
                        subtract_r[4]       <=      match_blk_r[4] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [4]          <=      12'hfff                          ;
                end
            end 
            else begin
                subtract_r[4]               <=      subtract_r[4]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[5]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[5]) begin
                    if (base_blk_r > match_blk_r[5]) begin
                        subtract_r[5]       <=      base_blk_r - match_blk_r[5]     ;
                    end 
                    else begin
                        subtract_r[5]       <=      match_blk_r[5] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [5]          <=      12'hfff                           ;
                end
            end 
            else begin
                subtract_r[5]               <=      subtract_r[5]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[6]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[6]) begin
                    if (base_blk_r > match_blk_r[6]) begin
                        subtract_r[6]       <=      base_blk_r - match_blk_r[6]     ;
                    end 
                    else begin
                        subtract_r[6]       <=      match_blk_r[6] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [6]          <=      12'hfff                           ;
                end
            end 
            else begin
                subtract_r[6]               <=      subtract_r[6]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[7]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[7]) begin
                    if (base_blk_r > match_blk_r[7]) begin
                        subtract_r[7]       <=      base_blk_r - match_blk_r[7]     ;
                    end 
                    else begin
                        subtract_r[7]       <=      match_blk_r[7] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [7]          <=      12'hfff                          ;
                end
            end 
            else begin
                subtract_r[7]               <=      subtract_r[7]                   ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            subtract_r[8]                   <=      'b0                             ;
        end
        else begin
            if (finish_flag1) begin
                if (match_blk_ena_r[8]) begin
                    if (base_blk_r > match_blk_r[8]) begin
                        subtract_r[8]       <=      base_blk_r - match_blk_r[8]     ;
                    end 
                    else begin
                        subtract_r[8]       <=      match_blk_r[8] - base_blk_r     ;
                    end
                end 
                else begin
                    subtract_r [8]          <=      12'hfff                         ;
                end
            end 
            else begin
                subtract_r[8]               <=      subtract_r[8]                   ;
            end
        end
    end



///////////////////////////////////////////////////////////////////////////////////////////



    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            compare_2x1[0]                  <=          'b0                         ;
            compare_2x1[1]                  <=          'b0                         ;
            compare_2x1[2]                  <=          'b0                         ;
            compare_2x1[3]                  <=          'b0                         ; 
        end
        else begin
            if (finish_flag2) begin
                compare_2x1[0]              <= (subtract_r[0] < subtract_r[1]) ? {4'h0,subtract_r[0]} : {4'h1,subtract_r[1]};
                compare_2x1[1]              <= (subtract_r[2] < subtract_r[3]) ? {4'h2,subtract_r[2]} : {4'h3,subtract_r[3]};
                compare_2x1[2]              <= (subtract_r[4] < subtract_r[5]) ? {4'h4,subtract_r[4]} : {4'h5,subtract_r[5]};
                compare_2x1[3]              <= (subtract_r[6] < subtract_r[7]) ? {4'h6,subtract_r[6]} : {4'h7,subtract_r[7]};
            end
            else begin
                compare_2x1[0]              <= compare_2x1[0]                       ;
                compare_2x1[1]              <= compare_2x1[1]                       ;
                compare_2x1[2]              <= compare_2x1[2]                       ;
                compare_2x1[3]              <= compare_2x1[3]                       ;
            end
        end
    end


    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            compare_2x1_stage2[0]           <=    'b0                               ;
            compare_2x1_stage2[1]           <=    'b0                               ;
        end     
        else begin
            if (finish_flag3_1) begin
                compare_2x1_stage2[0]       <=    (compare_2x1[0][11:0] < compare_2x1[1][11:0]) ? compare_2x1[0] : compare_2x1[1];
                compare_2x1_stage2[1]       <=    (compare_2x1[2][11:0] < compare_2x1[3][11:0]) ? compare_2x1[2] : compare_2x1[3];
            end 
            else begin
                compare_2x1_stage2[0]       <=    compare_2x1_stage2[0]             ;
                compare_2x1_stage2[1]       <=    compare_2x1_stage2[1]             ;
            end
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            compare_2x1_stage3              <=    'b0                               ;
        end
        else begin
            if (finish_flag3_2) begin
                compare_2x1_stage3          <=    (compare_2x1_stage2[0][11:0] < compare_2x1_stage2[1][11:0]) ? compare_2x1_stage2[0] : compare_2x1_stage2[1];
            end 
            else begin
                compare_2x1_stage3          <=    compare_2x1_stage3                ;
            end  
        end
    end

    always @(posedge clk ) begin
        if (rst | flag_clr) begin
            final_compare                   <=    'b0                               ;
        end 
        else begin  
            if (finish_flag3_3) begin
                final_compare               <=    (subtract_r[8] < compare_2x1_stage3[11:0]) ? {4'h8,subtract_r[8]} : compare_2x1_stage3;
            end 
            else begin
                final_compare               <=    final_compare                     ;
            end
        end
    end

always @(posedge clk ) begin
    if (rst | flag_clr) begin
        minimum_id                          <=    9'hf                              ;
        SAD                                 <=    12'hfff                           ;
    end
    else begin
        if (finish_flag3_4) begin
            minimum_id                      <=    final_compare[15:12]              ;
            SAD                             <=    final_compare[11: 0]              ;
        end
        else begin
            minimum_id                      <=    minimum_id                        ;
            SAD                             <=    SAD                               ;
        end
    end
end

always @(posedge clk ) begin
    if (rst | flag_clr) begin
        vector_row                          <=      'b0                             ;
        vector_col                          <=      'b0                             ;
    end 
    else begin
        if (finish_flag3_4) begin
            case (final_compare[15:12])
                4'h0: begin
                    vector_row              <=       0                              ;
                    vector_col              <=       0                              ;
                end
                4'h1: begin
                    if (matching_type == 2'b00 || matching_type == 2'b11) begin
                        vector_row          <=      -2                              ;
                        vector_col          <=       0                              ;
                    end
                    else if (matching_type == 2'b01) begin
                        vector_row          <=      -1                              ;
                        vector_col          <=       0                              ;
                    end
                    else begin
                        vector_row          <=       0                              ;
                        vector_col          <=       1                              ;
                    end
                end
                4'h2: begin
                    if (matching_type == 2'b00 || matching_type == 2'b11) begin
                        vector_row          <=      -1                              ;
                        vector_col          <=       1                              ;
                    end
                    else if (matching_type == 2'b01) begin
                        vector_row          <=       0                              ;
                        vector_col          <=       1                              ;
                    end
                    else begin
                        vector_row          <=       1                              ;
                        vector_col          <=       1                              ;
                    end
                end
                4'h3: begin
                    if (matching_type == 2'b00 || matching_type == 2'b11) begin
                        vector_row          <=       0                              ;
                        vector_col          <=       2                              ;
                    end
                    else if (matching_type == 2'b01) begin
                        vector_row          <=       1                              ;
                        vector_col          <=       0                              ;
                    end
                    else begin
                        vector_row          <=       1                              ;
                        vector_col          <=       0                              ;
                    end
                end
                4'h4: begin
                    if (matching_type == 2'b00 || matching_type == 2'b11) begin
                        vector_row          <=       1                              ;
                        vector_col          <=       1                              ;
                    end
                    else begin
                        vector_row          <=       0                              ;
                        vector_col          <=      -1                              ;
                    end
                end
                4'h5: begin
                    vector_row              <=       2                              ;
                    vector_col              <=       0                              ;
                end
                4'h6: begin
                    vector_row              <=       1                              ;
                    vector_col              <=      -1                              ;
                end
                4'h7: begin
                    vector_row              <=       0                              ;
                    vector_col              <=      -2                              ;
                end
                4'h8:begin
                    vector_row              <=      -1                              ;
                    vector_col              <=      -1                              ;
                end
                default: begin
                    vector_row              <=      'b0                             ;
                    vector_col              <=      'b0                             ;
                end
            endcase
        end 
        else begin
            vector_row                      <=      vector_row                      ;
            vector_col                      <=      vector_col                      ;
        end
    end
end

endmodule
