/*
	Team ID		:	SM#1280
	Author list	: 	Krithik sankar, Ayush Mittal
	Filename		: 	SM_1280_message.v
	Theme			:	Sankatmochan Bot
	Function		:	message	
	Global Variables : None
		
*/
	

/*

Function Nmae :	message
Input 		  :	CLOCK,sensor,node_detect,node_no, in_scan,unit, is_stop,
Output 		  :	O_TX_SERIAL ,S3,led1 ,led2 ,led3 ,mpu_second, pu_count, mpu_count,w_count

Logic			  :	It implements the fault detection and resolving algorithm, along with that it manages the messages to be transmitted . Faults in each unit are managed and stored seperately
						in variables. Each time the bot enters the unit it discards or detect a paticular fault depending upon the data stored in these variables. 

Example Call  :	module message(

						CLOCK(CLOCK),
						.O_TX_SERIAL(O_TX_SERIAL),
							
						.sensor(sensor),
						.S3(S3),
							
						.node_detect(node_detect),     
						.node_no(node_no),  
					
						.led1(led1),		
						.led2(led2),
						.led3(led3),
							
						.in_scan(in_scan),
						.unit(unit),
						.is_stop(is_stop),
						
						.pu_count(pu_count),
						.mpu_count(mpu_count),
						.w_count(w_count)
					);	

*/
module message(

	//uart variables
	input CLOCK,
	output O_TX_SERIAL,

	
	//colour sensor variables
	input sensor,
	output S3,
	
	//node detection varialbles, input from traversal module
	input node_detect,     // if 1 then node detected
	input [5:0] node_no,   // node number, detected from traversal module 
	
	//led variables
	output reg [2:0] led1,			//To assign color to the led
	output reg [2:0] led2,
	output reg [2:0] led3,			// all these are mapped to hardware pins
	
	
	//traversal variables
	input in_scan,					// input from traversal , indicates whether the bot is scanning or not
	input [2:0] unit,				// tells which unit ,the bot is scanning
	input is_stop,					// marks the end of run to blink white led
	
	
	output reg [7:0] pu_count,
	output reg [7:0] mpu_count,		// output to traversal , conveys whether the bot has to come back or not.
	output reg [7:0] w_count
);
				
	
//uart variables
reg [95:0] 	data=0;				// data to be transmitted
reg [95:0] 	trans_data;			// temperorary variable used to construct message
reg [3:0] 	no_of_bytes;		// coveys the no. of bytes to be transmitted to the uart module 
reg 			valid_uart=0;		// if 1 then uart module will transmit the data
wire 			done;					// if 1 then uart module has transmitted the data			
reg [2:0] transmit_count=0;	// no. of times the uart module has to transmit the same data 

//color sensor variables
wire [2:0] 	color;						// color from color_sensor module
reg [2:0] 	prev_color=3'b000;		//to keep track of previous color given by the sensor 
reg [2:0] 	prev_color_trans=3'b000;// prev color transmitted
wire 			valid_color;				// indicates ,data from color sensor is valid 
reg 			measure=1;					// reset for color senor 
reg [7:0] 	color_count;				// to sample the incomming color until a threshold is crossed

//led variables
reg led_valid=0;							// used to indicate whether the message has to be transmitted or not through zigbee
reg [2:0]temp_led=3'b111;				// temporary variable for color checking

reg [4:0] mpu_patch_count=0;			//  all these variables, count the number of patches detected in a single scan 
reg [4:0] pu_patch_count=0;			//
reg [4:0] w_patch_count=0;				//

reg [4:0] mpu_color=0;					//  keeps a track of the number of patches in the corresponding unit
reg [4:0] pu_color=0;					//
reg [4:0] w_color=0;						//

reg [5:0] track=0;						// tracks the number of patches for which message has been transmitted in a single scan , cant be greater then 3 

//stop run variables
reg [2:0] stop_cnt=0;					// variables used for white led glowing 
reg [19:0] stop_count=0;				//

reg [26:0] master=0;						//variables used for white led glowing 


initial
begin
	led1=3'b111;			//initially the led does not glow
	led2=3'b111;
	led3=3'b111;
	
	pu_count=1;
	mpu_count=1;
	w_count=1;
	transmit_count=0;
end

main utt( .CLOCK(CLOCK),.TX_BYTE(data), .TX_DATA_VALID(valid_uart),.O_TX_SERIAL(O_TX_SERIAL), .O_TX_DONE(done),.no_of_bytes(no_of_bytes),.transmit_count(transmit_count));
	
colour_sensor utt1( .sensor(sensor), .measure(measure), .clk(CLOCK), .S3(S3),	.color(color), .valid(valid_color));



localparam scan				=	4'b0000;  // decides the unit to be managed depending upon the input (unit) from the traversal module
localparam mpu					=	4'b0001;	 // manages MPU unit 
localparam pu					=	4'b0010;	 // manages PU unit 
localparam w					=	4'b0011;	 // manages W unit 
localparam ssu					=	4'b0100;  // manages SSU unit 
localparam on					=	4'b0101;	 // state to implement white led
localparam off					=	4'b0110;	 // state to implemet white led

reg [3:0] nst	=	scan;



always @(posedge CLOCK)
begin

	
	case(nst)
	
	scan:	begin
			valid_uart=0;
	
			transmit_count=1;
		
				if(in_scan==0)
					nst=scan;
				else
				begin
					if((unit==1)&&(mpu_count>0))
						nst=mpu;
						
					else if((unit==2)&&(pu_count>0))
						nst=pu;
						
					else if((unit==3)&&(w_count>0))
						nst=w;
						
					else if((unit==4))
						nst=ssu;		
						
						
					if(is_stop==1)
						nst=on;
					
				end
			end
	
	mpu:	begin
			
			if (valid_color)                   //data for colour
				begin
				
					if (prev_color==color)        // sampling the color
						color_count=color_count+1;
					
					
					prev_color=color;
					
					if(color_count>14) 				// if we receive a color consecutively for more than some threshold then only we say a color is detected, this is used to prevent faulty color values detected by the bot while making a transition from white patch to color patch  
					begin
					
						color_count=0;
						if (color==3'b000)
							prev_color_trans=3'b000;
							
						if (color!=prev_color_trans && (color!=3'b000) && done)
							begin
							
								trans_data[47:0]=48'b010101010101000001001101001011010100100101010011;			//SI at MPU
								
								if(color==3'b001)
									trans_data[95:48]=48'b000010100010001100101101010010010100011000101101;		//red
								else if(color==3'b010)
									trans_data[95:48]=48'b000010100010001100101101010101000100001100101101;		//green
								else if(color==3'b011)
									trans_data[95:48]=48'b000010100010001100101101010100110100001100101101;		//blue
								
								no_of_bytes=12;
								//assign data here
								
								mpu_patch_count=mpu_patch_count+1;
								
								if((mpu_patch_count>mpu_color)&&(track<3))
								begin
									mpu_color=mpu_color+1;
									track=track+1;
									
									data=trans_data;
									prev_color_trans=color;
									
									//led working
									if (prev_color_trans==3'b001)			//red color
										temp_led=3'b011;
									else if (prev_color_trans==3'b010)	//green color
										temp_led=3'b101;
									else if (prev_color_trans==3'b011)	//blue color
										temp_led=3'b110;
								
									if(led1==3'b111)
									begin
										led1=temp_led;
										led_valid=1;
									end
									
									else if(led2==3'b111)
									begin
										led2=temp_led;
										led_valid=1;
									end
									
									else if(led3==3'b111)
									begin	
										led3=temp_led;
										led_valid=1;
									end
									
									else
										led_valid=0;	
									
									if(led_valid)				//making valid high to transmit message via uart module
										valid_uart=1;	
									else
										valid_uart=0;
								end//(second=0)
								
								else
								begin
									valid_uart=0;
									if(track>=3)
									mpu_count=2;
									else mpu_count=1;
									
								end
								
						end // color!=prev
						
						//prev_color=color;
		
					end // count>13
					
					else
					begin
						valid_uart=0;
						nst=mpu;
					end
						
				end // valid_color
				
			else valid_uart=0;
				
				
				
				
				if(in_scan==1)
					nst=mpu;
				else if(in_scan==0)
				begin
					nst=scan;
					mpu_count=mpu_count-1;
					mpu_patch_count=0;
					track=0;
				end
					
		
		
			end // mpu begin end
			
			
pu:	begin
			
			if (valid_color)                   //data for colour
				begin
				
					if (prev_color==color)        // sampling the color
						color_count=color_count+1;
					
					
					prev_color=color;
					
					if(color_count>16) 				// if we receive a color consecutively for more than some threshold then only we say a color is detected, this is used to prevent faulty color values detected by the bot while making a transition from white patch to color patch  
					begin
					
						color_count=0;
						if (color==3'b000)
							prev_color_trans=3'b000;
							
						if (color!=prev_color_trans && (color!=3'b000) && done)
							begin
							
								trans_data[39:0]=40'b0101010101010000001011010100100101010011;			//SI at PU
									
									if(color==3'b001)
										trans_data[87:40]=48'b000010100010001100101101010010010100011000101101;		//red
									else if(color==3'b010)
										trans_data[87:40]=48'b000010100010001100101101010101000100001100101101;		//green
									else if(color==3'b011)
										trans_data[87:40]=48'b000010100010001100101101010100110100001100101101;		//blue
									
									no_of_bytes=11;
//									//assign data here
								
								pu_patch_count=pu_patch_count+1;
								
								if((pu_patch_count>pu_color)&&(track<3))
								begin
									pu_color=pu_color+1;
									track=track+1;
									
									data=trans_data;
									prev_color_trans=color;
									
									//led working
									if (prev_color_trans==3'b001)			//red color
										temp_led=3'b011;
									else if (prev_color_trans==3'b010)	//green color
										temp_led=3'b101;
									else if (prev_color_trans==3'b011)	//blue color
										temp_led=3'b110;
								
									if(led1==3'b111)
									begin
										led1=temp_led;
										led_valid=1;
									end
									
									else if(led2==3'b111)
									begin
										led2=temp_led;
										led_valid=1;
									end
									
									else if(led3==3'b111)
									begin	
										led3=temp_led;
										led_valid=1;
									end
									
									else
										led_valid=0;	
									
									if(led_valid)				//making valid high to transmit message via uart module
										valid_uart=1;	
									else
										valid_uart=0;
								end//(second=0)
								
								else
								begin
									valid_uart=0;
									if(track>=3)
									pu_count=2;
									else pu_count=1;
									
								end
								
						end // color!=prev
						
						//prev_color=color;
		
					end // count>13
					
					else
					begin
						valid_uart=0;
						nst=pu;
					end
						
				end // valid_color
				
			else valid_uart=0;
				
				
				
				
				if(in_scan==1)
					nst=pu;
				else if(in_scan==0)
				begin
					nst=scan;
					pu_count=pu_count-1;
					pu_patch_count=0;
					track=0;
				end
					
		
		
			end // pu begin end
			
w:	begin
			
			if (valid_color)                   //data for colour
				begin
				
					if (prev_color==color)        // sampling the color
						color_count=color_count+1;
					
					
					prev_color=color;
					
					if(color_count>15) 				// if we receive a color consecutively for more than some threshold then only we say a color is detected, this is used to prevent faulty color values detected by the bot while making a transition from white patch to color patch  
					begin
					
						color_count=0;
						if (color==3'b000)
							prev_color_trans=3'b000;
							
						if (color!=prev_color_trans && (color!=3'b000) && done)
							begin
							
								trans_data[31:0]=32'b01010111001011010100100101010011;			//SI at W
									
									if(color==3'b001)
										trans_data[79:32]=48'b000010100010001100101101010010010100011000101101;		//red
									else if(color==3'b010)
										trans_data[79:32]=48'b000010100010001100101101010101000100001100101101;		//green
									else if(color==3'b011)
										trans_data[79:32]=48'b000010100010001100101101010100110100001100101101;		//blue
									
									no_of_bytes=10;
//									//assign data here
								
								w_patch_count=w_patch_count+1;
								
								if((w_patch_count>w_color)&&(track<3))
								begin
									pu_color=pu_color+1;
									track=track+1;
									
									data=trans_data;
									prev_color_trans=color;
									
									//led working
									if (prev_color_trans==3'b001)			//red color
										temp_led=3'b011;
									else if (prev_color_trans==3'b010)	//green color
										temp_led=3'b101;
									else if (prev_color_trans==3'b011)	//blue color
										temp_led=3'b110;
								
									if(led1==3'b111)
									begin
										led1=temp_led;
										led_valid=1;
									end
									
									else if(led2==3'b111)
									begin
										led2=temp_led;
										led_valid=1;
									end
									
									else if(led3==3'b111)
									begin	
										led3=temp_led;
										led_valid=1;
									end
									
									else
										led_valid=0;	
									
									if(led_valid)				//making valid high to transmit message via uart module
										valid_uart=1;	
									else
										valid_uart=0;
								end//(second=0)
								
								else
								begin
									valid_uart=0;
									if(track>=3)
									w_count=2;
									else w_count=1;
									
								end
								
						end // color!=prev
						
						//prev_color=color;
		
					end // count>13
					
					else
					begin
						valid_uart=0;
						nst=w;
					end
						
				end // valid_color
				
			else valid_uart=0;
				
				
				
				
				if(in_scan==1)
					nst=w;
				else if(in_scan==0)
				begin
					nst=scan;
					w_count=w_count-1;
					w_patch_count=0;
					track=0;
				end
					
		
		
			end // w begin end		
								
	ssu:		begin
				transmit_count=0;
				
				if (valid_color)                   //data for colour
					begin
					
						if (prev_color==color)        // sampling the color
							color_count=color_count+1;
					
						prev_color=color;
						
						if(color_count>15) 				// if we receive a color consecutively for more than some threshold then only we say a color is detected, this is used to prevent faulty color values detected by the bot while making a transition from white patch to color patch  
							begin
							
								color_count=0;
								if (color==3'b000)
									prev_color_trans=3'b000;
									
								if (color!=prev_color_trans && (color!=3'b000) && done)
									begin
								
										trans_data[47:0]=48'b010101010101001101010011001011010101001001000110;		//FR at SSU
			
										no_of_bytes=12;
										
										if(color==3'b001)
											trans_data[95:48]=48'b000010100010001100101101010010010100011000101101;		//red
										else if(color==3'b010)
											trans_data[95:48]=48'b000010100010001100101101010101000100001100101101;		//green
										else if(color==3'b011)
											trans_data[95:48]=48'b000010100010001100101101010100110100001100101101;		//blue
									
										data=trans_data;
										prev_color_trans=color;
										if (prev_color_trans==3'b001)			//red color
											temp_led=3'b011;
										else if (prev_color_trans==3'b010)	//green color
											temp_led=3'b101;
										else if (prev_color_trans==3'b011)	//blue color
											temp_led=3'b110;
										
										if((temp_led!=led1)&&(temp_led!=led2)&&(temp_led!=led3))
											led_valid=0;
										
										else
											begin			
												if(temp_led==led1)
												begin
													led_valid=1;
													led1=3'b111;
													transmit_count=transmit_count+1;
												end
											
												if(temp_led==led2)
												begin
													led_valid=1;
													led2=3'b111;
													transmit_count=transmit_count+1;
												end
											
												if(temp_led==led3)
												begin
													led_valid=1;
													led3=3'b111;
													transmit_count=transmit_count+1;
												end
											end
														
										
										if(led_valid)				//making valid high to transmit message via uart module
											valid_uart=1;
										else
											valid_uart=0;
								end
								
								//prev_color=color;
		
						end // count>13
					
						else
						begin
							valid_uart=0;
							nst=ssu;
						end
						
				end // valid_color
				
				else valid_uart=0;
				
				if(is_stop==1)
						nst=on;
		  
				if(in_scan==1)
					nst=ssu;
				else if(in_scan==0)
					nst=scan;
					
				if(is_stop==1)
						nst=on;
				
				
		end
				
				
		// state to implement white led						
	
	on		:	begin
					master=master+1;
					if(master<=50000000)
					begin
						stop_count=stop_count+1;
						if((stop_cnt==0)&&(stop_count<180000))
						begin
							led1=3'b011;
							led2=3'b011;
							led3=3'b011;
							stop_cnt=1;
						end
						else if((stop_cnt==1)&&(stop_count<440000))
						begin
							led1=3'b101;
							led2=3'b101;
							led3=3'b101;
							stop_cnt=2;
						end
						else if((stop_cnt==2)&&(stop_count<550000))
						begin
							led1=3'b110;
							led2=3'b110;
							led3=3'b110;
							stop_cnt=0;
						end
						else
							stop_count=0;
							
						nst=on;
					end
					else
					begin
						master=0;
						nst=off;
					end			
				end
				
				
	off	:	begin
					master=master+1;
					if(master<=50000000)
					begin
						led1=3'b111;
						led2=3'b111;
						led3=3'b111;
						nst=off;
					end
					else
					begin
						master=0;
						nst=on;
					end
				end
	
	endcase
end



endmodule
