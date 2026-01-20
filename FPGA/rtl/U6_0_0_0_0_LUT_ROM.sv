module multi_bram #( 
    parameter                           ADDR_WIDTH                 = 8      ,
    parameter                           DATA_WIDTH                 = 8      ,
    parameter                           DEPTH                      = 256  
)
(


    input                                                           clk                             ,
    input                                                           rst                             ,

    input                                                           re1                             ,
    input                                                           re2                             ,
    input                                                           re3                             ,
    input                                                           re4                             ,
    input                                                           re5                             ,
    input                                                           re6                             ,
    input                                                           re7                             ,
    input                                                           re8                             ,
    input                                                           re9                             ,

    input                     [ADDR_WIDTH-1: 0]                     rd_addr1                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr2                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr3                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr4                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr5                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr6                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr7                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr8                        ,
    input                     [ADDR_WIDTH-1: 0]                     rd_addr9                        ,

    output reg                [DATA_WIDTH-1: 0]                     rd_data1                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data2                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data3                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data4                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data5                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data6                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data7                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data8                        ,
    output reg                [DATA_WIDTH-1: 0]                     rd_data9                        
);

    (*ram_style="block"*) reg [DATA_WIDTH-1:0] bram [0:DEPTH-1];
    //read1
    always @(posedge clk)
    begin
        if(re1)
            rd_data1 <= bram[rd_addr1];
        else
            rd_data1 <= rd_data1;
    end
    //read2
    always @(posedge clk)
    begin
        if(re2)
            rd_data2 <= bram[rd_addr2];
        else
            rd_data2 <= rd_data2;
    end
        //read3
    always @(posedge clk)
    begin
        if(re3)
            rd_data3 <= bram[rd_addr3];
        else
            rd_data3 <= rd_data3;
    end
    //read4
    always @(posedge clk)
    begin
        if(re4)
            rd_data4 <= bram[rd_addr4];
        else
            rd_data4 <= rd_data4;
    end
    //read5
    always @(posedge clk)
    begin
        if(re5)
            rd_data5 <= bram[rd_addr5];
        else
            rd_data5 <= rd_data5;
    end
    //read6
    always @(posedge clk)
    begin
        if(re6)
            rd_data6 <= bram[rd_addr6];
        else
            rd_data6 <= rd_data6;
    end
    //read7
    always @(posedge clk)
    begin
        if(re7)
            rd_data7 <= bram[rd_addr7];
        else
            rd_data7 <= rd_data7;
    end
    //read8
    always @(posedge clk)
    begin
        if(re8)
            rd_data8 <= bram[rd_addr8];
        else
            rd_data8 <= rd_data8;
    end
    //read9
    always @(posedge clk)
    begin
        if(re9)
            rd_data9 <= bram[rd_addr9];
        else
            rd_data9 <= rd_data9;
    end
    
    //write
    always @(posedge clk)begin
        if(rst)
            bram[0]     <=   8'd128;
            bram[1]     <=   8'd128;
            bram[2]     <=   8'd128;
            bram[3]     <=   8'd127;
            bram[4]     <=   8'd127;
            bram[5]     <=   8'd126;
            bram[6]     <=   8'd125;
            bram[7]     <=   8'd125;
            bram[8]     <=   8'd124;
            bram[9]     <=   8'd122;
            bram[10]    <=   8'd121;
            bram[11]    <=   8'd120;
            bram[12]    <=   8'd118;
            bram[13]    <=   8'd117;
            bram[14]    <=   8'd115;
            bram[15]    <=   8'd113;
            bram[16]    <=   8'd111;
            bram[17]    <=   8'd109;
            bram[18]    <=   8'd107;
            bram[19]    <=   8'd105;
            bram[20]    <=   8'd102;
            bram[21]    <=   8'd100;
            bram[22]    <=   8'd98;
            bram[23]    <=   8'd95;
            bram[24]    <=   8'd93;
            bram[25]    <=   8'd90;
            bram[26]    <=   8'd88;
            bram[27]    <=   8'd85;
            bram[28]    <=   8'd83;
            bram[29]    <=   8'd80;
            bram[30]    <=   8'd78;
            bram[31]    <=   8'd75;
            bram[32]    <=   8'd72;
            bram[33]    <=   8'd70;
            bram[34]    <=   8'd67;
            bram[35]    <=   8'd65;
            bram[36]    <=   8'd62;
            bram[37]    <=   8'd60;
            bram[38]    <=   8'd57;
            bram[39]    <=   8'd55;
            bram[40]    <=   8'd53;
            bram[41]    <=   8'd50;
            bram[42]    <=   8'd48;
            bram[43]    <=   8'd46;
            bram[44]    <=   8'd44;
            bram[45]    <=   8'd42;
            bram[46]    <=   8'd40;
            bram[47]    <=   8'd38;
            bram[48]    <=   8'd36;
            bram[49]    <=   8'd34;
            bram[50]    <=   8'd32;
            bram[51]    <=   8'd30;
            bram[52]    <=   8'd28;
            bram[53]    <=   8'd27;
            bram[54]    <=   8'd25;
            bram[55]    <=   8'd24;
            bram[56]    <=   8'd22;
            bram[57]    <=   8'd21;
            bram[58]    <=   8'd20;
            bram[59]    <=   8'd19;
            bram[60]    <=   8'd17;
            bram[61]    <=   8'd16;
            bram[62]    <=   8'd15;
            bram[63]    <=   8'd14;
            bram[64]    <=   8'd13;
            bram[65]    <=   8'd12;
            bram[66]    <=   8'd11;
            bram[67]    <=   8'd11;
            bram[68]    <=   8'd10;
            bram[69]    <=   8'd9;
            bram[70]    <=   8'd8;
            bram[71]    <=   8'd8;
            bram[72]    <=   8'd7;
            bram[73]    <=   8'd7;
            bram[74]    <=   8'd6;
            bram[75]    <=   8'd6;
            bram[76]    <=   8'd5;
            bram[77]    <=   8'd5;
            bram[78]    <=   8'd4;
            bram[79]    <=   8'd4;
            bram[80]    <=   8'd4;
            bram[81]    <=   8'd3;
            bram[82]    <=   8'd3;
            bram[83]    <=   8'd3;
            bram[84]    <=   8'd3;
            bram[85]    <=   8'd2;
            bram[86]    <=   8'd2;
            bram[87]    <=   8'd2;
            bram[88]    <=   8'd2;
            bram[89]    <=   8'd2;
            bram[90]    <=   8'd1;
            bram[91]    <=   8'd1;
            bram[92]    <=   8'd1;
            bram[93]    <=   8'd1;
            bram[94]    <=   8'd1;
            bram[95]    <=   8'd1;
            bram[96]    <=   8'd1;
            bram[97]    <=   8'd1;
            bram[98]    <=   8'd1;
            bram[99]    <=   8'd1;
            bram[100]   <=   8'd0;
            bram[101]   <=   8'd0;
            bram[102]   <=   8'd0;
            bram[103]   <=   8'd0;
            bram[104]   <=   8'd0;
            bram[105]   <=   8'd0;
            bram[106]   <=   8'd0;
            bram[107]   <=   8'd0;
            bram[108]   <=   8'd0;
            bram[109]   <=   8'd0;
            bram[110]   <=   8'd0;
            bram[111]   <=   8'd0;
            bram[112]   <=   8'd0;
            bram[113]   <=   8'd0;
            bram[114]   <=   8'd0;
            bram[115]   <=   8'd0;
            bram[116]   <=   8'd0;
            bram[117]   <=   8'd0;
            bram[118]   <=   8'd0;
            bram[119]   <=   8'd0;
            bram[120]   <=   8'd0;
            bram[121]   <=   8'd0;
            bram[122]   <=   8'd0;
            bram[123]   <=   8'd0;
            bram[124]   <=   8'd0;
            bram[125]   <=   8'd0;
            bram[126]   <=   8'd0;
            bram[127]   <=   8'd0;
            bram[128]   <=   8'd0;
            bram[129]   <=   8'd0;
            bram[130]   <=   8'd0;
            bram[131]   <=   8'd0;
            bram[132]   <=   8'd0;
            bram[133]   <=   8'd0;
            bram[134]   <=   8'd0;
            bram[135]   <=   8'd0;
            bram[136]   <=   8'd0;
            bram[137]   <=   8'd0;
            bram[138]   <=   8'd0;
            bram[139]   <=   8'd0;
            bram[140]   <=   8'd0;
            bram[141]   <=   8'd0;
            bram[142]   <=   8'd0;
            bram[143]   <=   8'd0;
            bram[144]   <=   8'd0;
            bram[145]   <=   8'd0;
            bram[146]   <=   8'd0;
            bram[147]   <=   8'd0;
            bram[148]   <=   8'd0;
            bram[149]   <=   8'd0;
            bram[150]   <=   8'd0;
            bram[151]   <=   8'd0;
            bram[152]   <=   8'd0;
            bram[153]   <=   8'd0;
            bram[154]   <=   8'd0;
            bram[155]   <=   8'd0;
            bram[156]   <=   8'd0;
            bram[157]   <=   8'd0;
            bram[158]   <=   8'd0;
            bram[159]   <=   8'd0;
            bram[160]   <=   8'd0;
            bram[161]   <=   8'd0;
            bram[162]   <=   8'd0;
            bram[163]   <=   8'd0;
            bram[164]   <=   8'd0;
            bram[165]   <=   8'd0;
            bram[166]   <=   8'd0;
            bram[167]   <=   8'd0;
            bram[168]   <=   8'd0;
            bram[169]   <=   8'd0;
            bram[170]   <=   8'd0;
            bram[171]   <=   8'd0;
            bram[172]   <=   8'd0;
            bram[173]   <=   8'd0;
            bram[174]   <=   8'd0;
            bram[175]   <=   8'd0;
            bram[176]   <=   8'd0;
            bram[177]   <=   8'd0;
            bram[178]   <=   8'd0;
            bram[179]   <=   8'd0;
            bram[180]   <=   8'd0;
            bram[181]   <=   8'd0;
            bram[182]   <=   8'd0;
            bram[183]   <=   8'd0;
            bram[184]   <=   8'd0;
            bram[185]   <=   8'd0;
            bram[186]   <=   8'd0;
            bram[187]   <=   8'd0;
            bram[188]   <=   8'd0;
            bram[189]   <=   8'd0;
            bram[190]   <=   8'd0;
            bram[191]   <=   8'd0;
            bram[192]   <=   8'd0;
            bram[193]   <=   8'd0;
            bram[194]   <=   8'd0;
            bram[195]   <=   8'd0;
            bram[196]   <=   8'd0;
            bram[197]   <=   8'd0;
            bram[198]   <=   8'd0;
            bram[199]   <=   8'd0;
            bram[200]   <=   8'd0;
            bram[201]   <=   8'd0;
            bram[202]   <=   8'd0;
            bram[203]   <=   8'd0;
            bram[204]   <=   8'd0;
            bram[205]   <=   8'd0;
            bram[206]   <=   8'd0;
            bram[207]   <=   8'd0;
            bram[208]   <=   8'd0;
            bram[209]   <=   8'd0;
            bram[210]   <=   8'd0;
            bram[211]   <=   8'd0;
            bram[212]   <=   8'd0;
            bram[213]   <=   8'd0;
            bram[214]   <=   8'd0;
            bram[215]   <=   8'd0;
            bram[216]   <=   8'd0;
            bram[217]   <=   8'd0;
            bram[218]   <=   8'd0;
            bram[219]   <=   8'd0;
            bram[220]   <=   8'd0;
            bram[221]   <=   8'd0;
            bram[222]   <=   8'd0;
            bram[223]   <=   8'd0;
            bram[224]   <=   8'd0;
            bram[225]   <=   8'd0;
            bram[226]   <=   8'd0;
            bram[227]   <=   8'd0;
            bram[228]   <=   8'd0;
            bram[229]   <=   8'd0;
            bram[230]   <=   8'd0;
            bram[231]   <=   8'd0;
            bram[232]   <=   8'd0;
            bram[233]   <=   8'd0;
            bram[234]   <=   8'd0;
            bram[235]   <=   8'd0;
            bram[236]   <=   8'd0;
            bram[237]   <=   8'd0;
            bram[238]   <=   8'd0;
            bram[239]   <=   8'd0;
            bram[240]   <=   8'd0;
            bram[241]   <=   8'd0;
            bram[242]   <=   8'd0;
            bram[243]   <=   8'd0;
            bram[244]   <=   8'd0;
            bram[245]   <=   8'd0;
            bram[246]   <=   8'd0;
            bram[247]   <=   8'd0;
            bram[248]   <=   8'd0;
            bram[249]   <=   8'd0;
            bram[250]   <=   8'd0;
            bram[251]   <=   8'd0;
            bram[252]   <=   8'd0;
            bram[253]   <=   8'd0;
            bram[254]   <=   8'd0;
            bram[255]   <=   8'd0;
    end
endmodule