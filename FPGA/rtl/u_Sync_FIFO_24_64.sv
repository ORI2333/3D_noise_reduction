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
    parameter                           DATA_WIDTH         = 24    ,//FIFO位锟斤拷
    parameter                           DATA_DEPTH         = 64     //FIFO锟斤拷锟�
)
(
    input                               clk                        ,//系统时锟斤拷
    input                               rst                        ,//锟酵碉拷平锟斤拷效锟侥革拷位锟脚猴拷
    input              [DATA_WIDTH-1:0] data_in                    ,//写锟斤拷锟斤拷锟斤拷锟�
    input                               rd_en                      ,//锟斤拷使锟斤拷锟脚号ｏ拷锟竭碉拷平锟斤拷效
    input                               wr_en                      ,//写使锟斤拷锟脚号ｏ拷锟竭碉拷平锟斤拷效
						                                        
    output reg                [  63: 0] data_out                   ,//锟斤拷锟斤拷锟斤拷锟斤拷锟�
    output                              empty                      ,//锟秸憋拷志锟斤拷锟竭碉拷平锟斤拷示锟斤拷前FIFO锟窖憋拷写锟斤拷
    output                              full                       ,//锟斤拷锟斤拷志锟斤拷锟竭碉拷平锟斤拷示锟斤拷前FIFO锟窖憋拷锟斤拷锟斤拷
    output                              almost_full                 
);

//reg define
//锟矫讹拷维锟斤拷锟斤拷实锟斤拷RAM
    reg                       [   7: 0]         			  fifo_buffer[DATA_DEPTH-1:0] ;
    reg                       [$clog2(DATA_DEPTH): 0]         wr_ptr                      ;//写锟斤拷址指锟诫，位锟斤拷锟斤拷一位	
    reg                       [$clog2(DATA_DEPTH): 0]         rd_ptr                      ;//锟斤拷锟斤拷址指锟诫，位锟斤拷锟斤拷一位	
 
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



//写锟斤拷锟斤拷,锟斤拷锟斤拷写锟斤拷址
always @ (posedge clk) begin
	if (true_wr_en)begin//写使锟斤拷锟斤拷效锟揭凤拷锟斤拷
		fifo_buffer[wr_ptr_true + 2] <= data_in[23:16]			;
        fifo_buffer[wr_ptr_true + 1] <= data_in[15: 8]			;
		fifo_buffer[wr_ptr_true    ] <= data_in[ 7: 0]			;
	end
end


//锟斤拷锟斤拷锟斤拷,锟斤拷锟铰讹拷锟斤拷址
always @ (posedge clk or posedge rst) begin
	if (rst)
        data_out 				<= 'd0                     		;
	else if (true_rd_en) begin//锟斤拷使锟斤拷锟斤拷效锟揭非匡拷
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
