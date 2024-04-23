`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/01/2024 10:40:29 AM
// Design Name: 
// Module Name: tb_FIR
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


module tb_bandPass();

    reg aclk, resetn, s_axis_tvalid, s_axis_tlast, s00_axi_aclk, s00_axi_aresetn;
    reg signed [15:0] s_axis_tdata;
    wire m_axis_tvalid;
    wire [3:0] m_axis_tkeep;
    wire signed [15:0] m_axis_tdata;
    wire m_axis_tready;
    
    reg dm_axis_tready;
    wire dm_axis_tvalid;
    wire signed [15:0] dm_axis_tdata;
    
  //  wire s00_axi_awvalid, s00_axi_awready, s00_axi_wvalid, s00_axi_wready;
    
   // assign s00_axi_awvalid = 1'b0;
   // assign s00_axi_awready = 1'b0;
   // assign s00_axi_wvalid = 1'b0;
   // assign s00_axi_wready = 1'b0;
    
    //wire [31:0] sampling_delay;
   // wire [31:0] averaging_point;
    
    //assign sampling_delay = 32'd100;
    //assign averaging_point = 32'd10;
 
    
    //10 MHz, 100ns clock
    always begin
       aclk = 1; s00_axi_aclk = 1; #50;
       aclk = 0; s00_axi_aclk = 0; #50;
    end
   
    
    initial begin
        resetn = 1; s00_axi_aresetn = 1; #400;
        resetn = 0; s00_axi_aresetn = 0; #400;
        resetn = 1; s00_axi_aresetn = 1; #400;
    end
    
    initial begin
        s_axis_tvalid = 0; s_axis_tlast =0; #800;
        s_axis_tvalid = 1; s_axis_tlast =1; #800;
    end
    
    initial begin
         dm_axis_tready = 0; #900;
         dm_axis_tready = 1; #900;
    end
    
    /* Instantiate bandPass module to test. */
    bandPass #(
       //10MHz
      .b0 ( 28'd33548108),//numerators
      .b1 (-28'd67096098),
      .b2 ( 28'd33548108),
      .a1 (-28'd67096098),//denominators
      .a2 ( 28'd33541784 )  
      
      //1MHz
   /*   .b0 ( 20'd261650),//numerators
      .b1 (-20'd523209),
      .b2 ( 20'd261650),
      .a1 (-20'd523209),//denominators
      .a2 ( 20'd261157)     */
    ) inst_bandPass
    (
      .aclk(aclk),
      .resetn(resetn),
      .s_axis_tdata(s_axis_tdata),    
      .s_axis_tlast(s_axis_tlast),   
      .s_axis_tvalid(s_axis_tvalid), 
      .s_axis_tready(s_axis_tready), 
      .m_axis_tdata(m_axis_tdata),
      .m_axis_tlast(m_axis_tlast),  
      .m_axis_tvalid(m_axis_tvalid), 
      .m_axis_tready(m_axis_tready)     
    );
    
    dataSampling_100kHz_v1_0  inst_dataSampling_100kHz_0
    (
      .aclk(aclk),
      .resetn(resetn),
      .s_axis_tdata(m_axis_tdata),    
      .s_axis_tlast(m_axis_tlast),   
      .s_axis_tvalid(m_axis_tvalid), 
      .s_axis_tready(m_axis_tready), 
      .m_axis_tdata(dm_axis_tdata),
      .m_axis_tlast(dm_axis_tlast),  
      .m_axis_tvalid(dm_axis_tvalid), 
      .m_axis_tready(dm_axis_tready),
      .s00_axi_aclk(s00_axi_aclk),
      .s00_axi_aresetn(s00_axi_aresetn)
    );
    

    reg [4:0] state_reg;
    reg [15:0] cntr;
    
    parameter wvfm_period = 16'd1216; //4166 for 300Hz
    
    parameter init               = 5'd0;
    parameter sendSample0        = 5'd1;
    parameter sendSample1        = 5'd2;
    parameter sendSample2        = 5'd3;
    parameter sendSample3        = 5'd4;
    parameter sendSample4        = 5'd5;
    parameter sendSample5        = 5'd6;
    parameter sendSample6        = 5'd7;
    parameter sendSample7        = 5'd8;
    
    /* This state machine generates a 1/(8*100ns*wvfm_period) sinusoid. */
    always @ (posedge aclk or negedge resetn)
        begin
            if (resetn == 1'b0)
                begin
                    cntr <= 16'd0;
                    s_axis_tdata <= 16'd0;
                    state_reg <= init;
                end
            else
                begin
                    case (state_reg)
                        init : //0
                            begin
                                cntr <= 16'd0;
                                s_axis_tdata <= 16'h0000;
                                state_reg <= sendSample0;
                            end
                            
                        sendSample0 : //1
                            begin
                                s_axis_tdata <= 16'h0000;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample1;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample0;
                                    end
                            end 
                        
                        sendSample1 : //2
                            begin
                                s_axis_tdata <= 16'h5A81;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample2;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample1;
                                    end
                            end 
                        
                        sendSample2 : //3
                            begin
                                s_axis_tdata <= 16'h7FFF;//16'h1fff;//
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample3;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample2;
                                    end
                            end 
                        
                        sendSample3 : //4
                            begin
                                s_axis_tdata <= 16'h5A81;//16'h16a0;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample4;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample3;
                                    end
                            end 
                        
                        sendSample4 : //5
                            begin
                                s_axis_tdata <= 16'hffff;
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample5;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample4;
                                    end
                            end 
                        
                        sendSample5 : //6
                            begin
                                s_axis_tdata <=16'hA57e;// 16'he960;// 
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample6;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample5;
                                    end
                            end 
                        
                        sendSample6 : //6
                            begin
                                s_axis_tdata <=16'h8001; // 16'he001;//
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample7;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample6;
                                    end
                            end 
                        
                        sendSample7 : //6
                            begin
                                s_axis_tdata <= 16'hA57e;//16'he960;// 
                                
                                if (cntr == (wvfm_period-1'b1))
                                    begin
                                        cntr <= 16'd0;
                                        state_reg <= sendSample0;
                                    end
                                else
                                    begin 
                                        cntr <= cntr + 1;
                                        state_reg <= sendSample7;
                                    end
                            end                     
                    
                    endcase
                end
        end
        
endmodule
