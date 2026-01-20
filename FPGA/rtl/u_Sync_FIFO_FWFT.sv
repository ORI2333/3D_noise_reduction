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


module    u_Sync_FIFO_FWFT
#(
    parameter                 DATA_WIDTH                  = 16    ,								//FIFOλ��
    parameter                 DATA_DEPTH                  = 640   //FIFO���?
)
(
    input                                               clk                         ,//ϵͳʱ��
    input                                               rst                         ,//�͵�ƽ��Ч�ĸ�λ�ź�
    input                     [DATA_WIDTH-1: 0]         data_in                     ,//д�������?
    input                                               rd_en                       ,//��ʹ���źţ��ߵ�ƽ��Ч
    input                                               wr_en                       ,//дʹ���źţ��ߵ�ƽ��Ч
						                                        
    output reg                [DATA_WIDTH-1: 0]         data_out                    ,//���������?
    output                                              empty                       ,//�ձ�־���ߵ�ƽ��ʾ��ǰFIFO�ѱ�д��
    output                                              full                         //����־���ߵ�ƽ��ʾ��ǰFIFO�ѱ�����
);
 
//reg define
//�ö�ά����ʵ��RAM
    reg                       [  DATA_WIDTH - 1: 0]         fifo_buffer[DATA_DEPTH-1  :0] ;
    reg                       [  10: 0]                       wr_ptr                      ;//д��ַָ�룬λ���һ�?	
    reg                       [  10: 0]                       rd_ptr                      ;//����ַָ�룬λ���һ�?	
 
//wire define
    wire                      [   9: 0]                       wr_ptr_true                 ;//��ʵд��ַָ��
    wire                      [   9: 0]                       rd_ptr_true                 ;//��ʵ����ַָ��
    wire                                                      wr_ptr_msb                  ;//д��ַָ���ַ���λ
    wire                                                      rd_ptr_msb                  ;//����ַָ���ַ���λ
 
    assign                              {wr_ptr_msb,wr_ptr_true}    = wr_ptr;//�����λ������λƴ��?
    assign                              {rd_ptr_msb,rd_ptr_true}    = rd_ptr;//�����λ������λƴ��?
 
//������,���¶���ַ
always @ (posedge clk) begin
	if (rst)
        data_out <= 'd0;
	else if (!empty)begin								//��ʹ����Ч�ҷǿ�
		data_out <= fifo_buffer[rd_ptr_true];
	end
    else begin
        data_out <= 'd0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        rd_ptr <= 'd0;
    end 
	else begin
		if (~empty && rd_en) begin
			if (rd_ptr[9:0] == DATA_DEPTH - 1) begin
				rd_ptr[10] <= ~rd_ptr[10];
				rd_ptr[9:0]<= 'b0 		 ;
			end 
			else begin
				rd_ptr 	   <= rd_ptr + 1 ;
			end
		end 
		else begin
			rd_ptr <= rd_ptr;
		end
	end
end


always @(posedge clk ) begin
	if (rst) begin
		wr_ptr <= 'b0;
	end else begin
		if (~full && wr_en) begin
			if (wr_ptr[9:0] == DATA_DEPTH - 1) begin
				wr_ptr[10] <= ~wr_ptr[10];
				wr_ptr[9:0]<= 'b0 	     ;
			end else begin
				wr_ptr 	   <= wr_ptr + 1 ;
			end
		end else begin
			wr_ptr <= wr_ptr;
		end
	end
end


//д����,����д��ַ
always @ (posedge clk) begin
	if (!full && wr_en)begin								//дʹ����Ч�ҷ���
		fifo_buffer[wr_ptr_true] <= data_in;
	end
end

//����ָʾ�ź�
//������λ���ʱ����ָ��׷������дָ�룬FIFO������
assign	empty = ( wr_ptr == rd_ptr );
//�����λ��ͬ��������λ���ʱ��дָ�볬����ָ��һȦ��FIFO��д��
assign	full  = ( (wr_ptr[10] != rd_ptr[10] ) && ( wr_ptr[9:0] == rd_ptr[9:0] ) );
 
endmodule
