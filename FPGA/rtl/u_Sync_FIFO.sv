`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2025/01/22 01:08:44
// Design Name: 
// Module Name: Async_FIFO_FWFT
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


module    Sync_FIFO_24_64
#(
    parameter                           DATA_WIDTH         = 24    ,//FIFO婵炶揪绲界粔褰掑极閹捐妫橀柕鍫濇椤忥拷
    parameter                           DATA_DEPTH         = 64     //FIFO闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌ㄩ悤鍌涘
)
(
    input                               clk                        ,//缂備緡鍨靛畷鐢靛垝濞差亜绫嶉柛顐ｆ礃閺呮悂鏌￠崒妯衡偓鏍偓姘炬嫹
    input                               rst                        ,//闂備浇娉曢崰鏍矗閾忕懓鏋堝璺侯儏椤忚埖顨ラ悙鏉戔枙闁轰焦鎹囧顒勫Χ閸℃浼撻梺杞扮閻楁捇寮幘瀵哥懝闁靛鏅滄禍銈夋煙閻ゎ垱鑵圭紓宥呮嚇閺屻劑鎮㈢拠鎻掝棝闂佺粯鑹鹃悺銊р偓姘炬嫹
    input              [DATA_WIDTH-1:0] data_in                    ,//闂佸憡鍔栭悷鈺呭极閹捐妫橀柕鍫濇椤忓爼姊虹捄銊ユ瀾闁哄顭烽獮蹇涙倻閼恒儲娅㈤梺鍝勫€堕崐鏍偓姘秺閺屻劑鎮ら崒娑橆伓
    input                               rd_en                      ,//闂備浇娉曢崰鎰板几婵犳艾绠柧姘€搁埢蹇涙⒑鐠恒劌鏋戦柡瀣煼楠炲繘鎮滈懞銉︽闂佺厧鐡ㄩ懝鎹愩亹閸ф鏅查煫鍥ㄦ煥椤忓爼姊虹捄銊ユ灁妞ゅ浚浜為崰濠冨緞鐎ｎ亶浼撳Δ鐘靛仦婵炲﹪寮幘璇叉闁靛牆妫楅鍫曟煛娓氬﹥瀚�
    input                               wr_en                      ,//闂佸憡鍔栭悷銈嗙箾閸ヮ剚鐓ラ柣鏂挎啞閻忣噣鏌熸搴″幋闁轰焦鎹囬幊妯侯潩椤掆偓婵炲洭鏌ㄥ┑鍡欑閻庢艾缍婇弻銊╂偄娓氼垯鐥紒鐐緲椤︽壆鈧艾缍婇悰顕€骞庨懞銉︽闂佸搫鍊堕崐鏍偓姘秺瀵偊鏁撻敓锟�
						                                        
    output reg                [  63: 0] data_out                   ,//闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌￠崒妯衡偓鏍偓姘秺閺屻劑鎮㈤崨濠勪紕闂佸綊顥撻崗姗€寮幘璇叉闁靛牆妫楅鍫曟⒑鐠恒劌娅愰柟鍑ゆ嫹
    output                              empty                      ,//闂備浇娉曢崰鎾剁懅闂佽褰冮鍡欌偓姘鳖攰缁犳稑螖閸涱喗娅㈤梺鍝勫€堕崐鏍偓姘秺閺屻劑鎮㈡笟顖欑棯缂佺偓婢橀ˇ鎵偓姘秺閻涱噣骞庨懞銉︽闂佸搫鍊堕崐鏍偓姘贡缁牆煤椤忓懏娅㈤梺鍝勫€堕崐鏍偓姘秺瀹曟粌鐣濈粋婊稯闂備浇娉曢崰鎾绘偘閵堝绠熼悗锝庡亜椤忓爼鏌涢幇顓犳噰闁轰焦鎹囧顒勫Χ閸℃浼�
    output                              full                       ,//闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌￠崒妯衡偓鏍偓姘鳖攰缁犳稑螖閸涱喗娅㈤梺鍝勫€堕崐鏍偓姘秺閺屻劑鎮㈡笟顖欑棯缂佺偓婢橀ˇ鎵偓姘秺閻涱噣骞庨懞銉︽闂佸搫鍊堕崐鏍偓姘贡缁牆煤椤忓懏娅㈤梺鍝勫€堕崐鏍偓姘秺瀹曟粌鐣濈粋婊稯闂備浇娉曢崰鎾绘偘閵堝绠熼悗锝庡亜椤忓爼姊虹捄銊ユ瀾闁哄顭烽獮蹇涙倻閼恒儲娅㈤梺鍝勫€堕崐鏍偓姘炬嫹
    output                              almost_full                 
);

//reg define
//闂備浇娉曢崰鎾绘偂椤愩倖濯奸悷娆忓椤忓墎绱撴担瑙勫唉闁轰焦鎹囧顒勫Χ閸℃浼撻梻浣芥硶閸犳劙寮告繝姘鐎瑰嫭澹嗛弶浠嬫⒑鐠恒劌鏋戦柡瀣煼楠炲繒绮欓惈婵�
    reg                       [   7: 0]         			  fifo_buffer[DATA_DEPTH-1:0] ;
    reg                       [$clog2(DATA_DEPTH): 0]         wr_ptr                      ;//闂佸憡鍔栭悷鈺呭极閹捐妫橀柕鍫濇椤忓爼鏌涜閸嬫捇鏌熺粙鎸庡枠闁轰焦鎸鹃幏鐘活敃椤掑倻顦繛杈剧到缁夊綊寮幘璇叉闁靛牆妫楅鍫曟⒑鐠恒劌鏋戦柡瀣煼楠炲繘鎽庨崒婊庝紘婵炶揪缍囬幏锟�	
    reg                       [$clog2(DATA_DEPTH): 0]         rd_ptr                      ;//闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌￠崒妯衡偓鏍偓姘秺瀹曟悂鍩€椤掑嫬绠伴柛銉墯閺呮悂鎮归崶璺轰壕缂佽鲸绻冮幏鍛吋婢跺娅㈤梺鍝勫€堕崐鏍偓姘秺閺屻劑鎮㈤崨濠勪紕闂佸湱鏌夊〒鍦博鐎涙ɑ濯撮柨鐕傛嫹	
 
    wire                      [$clog2(DATA_DEPTH)-1: 0]       wr_ptr_true                 ;
    wire                      [$clog2(DATA_DEPTH)-1: 0]       rd_ptr_true                 ;

    wire                                        			  true_wr_en                  ;
    wire                                        			  true_rd_en                  ;


    assign                      wr_ptr_true                 = wr_ptr[$clog2(DATA_DEPTH)-1: 0];
    assign                      rd_ptr_true                 = rd_ptr[$clog2(DATA_DEPTH)-1: 0];

    assign                      true_wr_en                  = wr_en & (~full);
    assign                      true_rd_en                  = rd_en & (~empty);


always @(posedge clk ) begin
	if (rst) begin
		rd_ptr  				<=  'd0												;
	end 
	else begin
		if (true_rd_en) begin
			if (rd_ptr_true + 8 >= DATA_DEPTH) begin
				rd_ptr[$clog2(DATA_DEPTH)-1  ]  	<= ~rd_ptr[$clog2(DATA_DEPTH)-1  ]			   	  	;
				rd_ptr[$clog2(DATA_DEPTH)-1: 0] 	<= 8 + rd_ptr_true - DATA_DEPTH ;
			end 
			else begin
				rd_ptr[$clog2(DATA_DEPTH)-1: 0] 	<= rd_ptr_true + 8				;
			end
		end
		else begin
			rd_ptr 				<= rd_ptr    										;
		end	
	end
end


always @(posedge clk ) begin
	if (rst) begin
		wr_ptr 					<= 'd0												;
	end 
	else begin
		if (true_wr_en) begin
			if (wr_ptr_true + 3 >= DATA_DEPTH) begin
				wr_ptr[$clog2(DATA_DEPTH)   ] 		<= ~wr_ptr[$clog2(DATA_DEPTH)   ]					;
				wr_ptr[$clog2(DATA_DEPTH)-1: 0]		<= 3 + wr_ptr_true - DATA_DEPTH	;
			end 
			else begin
                wr_ptr[$clog2(DATA_DEPTH)-1: 0]		<= wr_ptr_true + 3				;
			end
		end
		else begin
			wr_ptr			<= wr_ptr												;
		end	
	end
end



//闂佸憡鍔栭悷鈺呭极閹捐妫橀柕鍫濇椤忓爼姊虹捄銊ユ瀾闁哄顭烽獮蹇涙晸閿燂拷,闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌￠崒妯衡偓鏍偓姘秺瀹曟ê鈻庨幘瀛樻闂佸搫鍊堕崐鏍偓姘秺瀹曟悂鍩€閿燂拷
always @ (posedge clk) begin
	if (true_wr_en)begin//闂佸憡鍔栭悷銈嗙箾閸ヮ剚鐓ラ柣鏂挎啞閻忣噣鏌熸搴″幋闁轰焦鎹囧顒勫Χ閸℃浼撻梺杞扮閻楁捇寮幘璇茬妞ゆ挾鍋涘▓鈺呮煙妞嬪骸鍘撮柡浣规崌瀵剟濡堕崱妤婁紦
		fifo_buffer[wr_ptr_true + 2] <= data_in[23:16]			;
        fifo_buffer[wr_ptr_true + 1] <= data_in[15: 8]			;
		fifo_buffer[wr_ptr_true    ] <= data_in[ 7: 0]			;
	end
end


//闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂鏌￠崒妯衡偓鏍偓姘秺閺屻劑鎮㈤崨濠勪紕闂佺懓鍤栭幏锟�,闂備浇娉曢崰鎰板几婵犳艾绠柣鎴ｅГ閺呮悂姊洪悙顒€顎滄い鏃€鍔欓獮蹇涙倻閼恒儲娅㈤梺鍝勫€堕崐鏍偓姘秺瀹曟悂鍩€閿燂拷
always @ (posedge clk or posedge rst) begin
	if (rst)
        data_out 				<= 'd0                     		;
	else if (true_rd_en) begin//闂備浇娉曢崰鎰板几婵犳艾绠柧姘€搁埢蹇涙⒑鐠恒劌鏋戦柡瀣煼楠炲繘鎮滈懞銉︽闂佸搫鍊堕崐鏍偓姘秺瀵偊宕奸妷锔芥闂佽妞块崣鍐焽椤忓牆绀岄柍鈺佸暙椤忥拷
		data_out[31: 0] 		<= {fifo_buffer[rd_ptr_true + 3],fifo_buffer[rd_ptr_true + 2],fifo_buffer[rd_ptr_true + 1],fifo_buffer[rd_ptr_true]    };
        data_out[63:32] 		<= {fifo_buffer[rd_ptr_true + 7],fifo_buffer[rd_ptr_true + 6],fifo_buffer[rd_ptr_true + 5],fifo_buffer[rd_ptr_true + 4]};
	end
    else begin
        data_out 				<= data_out                		;
    end
end


    reg         [$clog2(DATA_DEPTH): 0]         Byte_Conter                 ;

	always @(posedge clk ) begin
		if (rst) begin
			Byte_Conter 			<= 			'b0 						;
		end else begin
			if (true_wr_en & true_rd_en) begin
				Byte_Conter 		<= 			Byte_Conter - 5 			;	
			end
			else if (true_wr_en & (~true_rd_en)) begin
				Byte_Conter			<= 			Byte_Conter + 3 			;
			end 
			else if (~true_wr_en & true_rd_en) begin
				Byte_Conter 		<= 			Byte_Conter - 8 			;
			end
			else begin
				Byte_Conter 		<= 			Byte_Conter 	 			;
			end
		end
	end


	assign 		empty  			    = Byte_Conter < 8 						;

    assign		full				= Byte_Conter + 3 > DATA_DEPTH			;
	assign  	almost_full 		= Byte_Conter + 6 > DATA_DEPTH 	 		;

endmodule
