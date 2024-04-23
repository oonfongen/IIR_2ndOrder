`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 04/16/2024 08:53:31 AM
// Design Name: 
// Module Name: IIR_2ndOrder
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


module IIR_2ndOrder #(

  parameter inout_width               = 16, //1 sign bit, 4 interger bit, 11 decimal width
  parameter inout_decimal_width       = 11,
  parameter gain_width                = 16, // 1 sign bit, 8 interger bit, 7 decimal bit
  parameter gain_decimal_width        = 7,//maximum gain: +/- 256
  parameter coefficient_width         = 28,
  parameter coefficient_decimal_width = 25,
  
  //internal width has to be the sum of <maximum interger width>
  //+ <maximum decimal width> + 1 extra overflow bit
  parameter internal_width            = 35, 
  //internal decimal width has to be the <maximum decimal width>
  parameter internal_decimal_width    = 25,
  
  parameter saturation_bit            = 32767 //assume output is 16 signed bit

  )(
  input aclk,
  input resetn,

  /* slave axis interface */
  input signed [inout_width-1:0] s_axis_tdata,
  input               s_axis_tlast,
  output reg          s_axis_tready,
  input               s_axis_tvalid,
  

  /* master axis interface */
  output reg signed [inout_width-1:0] m_axis_tdata,
  output reg                          m_axis_tlast,
  input                               m_axis_tready,
  output reg                          m_axis_tvalid,
  
  //control parameters
  input signed [coefficient_width-1:0] b0, 
  input signed [coefficient_width-1:0] b1,
  input signed [coefficient_width-1:0] b2,
  input signed [coefficient_width-1:0] a1,
  input signed [coefficient_width-1:0] a2,
  
  input signed [gain_width-1:0]        gain,
  input                                OnOff, 
 
  
  output signed [inout_width-1:0]      data_monitor
  );
  
  assign data_monitor = m_axis_tdata;

  localparam inout_integer_width       = inout_width - inout_decimal_width; /* compute integer width */
  localparam coefficient_integer_width = coefficient_width -coefficient_decimal_width; /* compute integer width */
  localparam gain_integer_width        = gain_width -gain_decimal_width;
  localparam internal_integer_width    = internal_width - internal_decimal_width; /* compute integer width */
  
  wire signed [inout_width-1:0] saturation;
  assign saturation = saturation_bit;
  
  //e and u have to be in the same scaling
  wire signed [internal_width-1:0] input_int; /* input data internal size */
  wire signed [internal_width-1:0] b0_int; /* coefficient internal size */
  wire signed [internal_width-1:0] b1_int; /* coefficient internal size */
  wire signed [internal_width-1:0] b2_int; /* coefficient internal size */
  wire signed [internal_width-1:0] a1_int; /* coefficient internal size */
  wire signed [internal_width-1:0] a2_int; /* coefficient internal size */
  wire signed [internal_width-1:0] gain_int; /* gain internal size */
  wire signed [internal_width-1:0] output_int; /* output internal size, before gain */
  wire signed [internal_width-1:0] gainOutput_int; /* output internal size, after gain */
  wire signed [internal_width-1:0] saturation_int;

  wire   signed  [internal_width+internal_width-1:0] prodTotal; //output of IIR
  wire   signed  [internal_width+internal_width-1:0] gainOutputTotal; //output of gain
  
  reg    signed  [internal_width+internal_width-1:0] sum22;
  reg    signed  [internal_width+internal_width-1:0] sum11;
   
  
    /* resize signals to internal width */
    /*to align the position of the decimal point */
  assign input_int      = { {(internal_integer_width-inout_integer_width){s_axis_tdata[inout_width-1]}},
                            s_axis_tdata,
                            {(internal_decimal_width-inout_decimal_width){1'b0}} };
  assign b0_int         = { {(internal_integer_width-coefficient_integer_width){b0[coefficient_width-1]}},
                            b0,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign b1_int         = { {(internal_integer_width-coefficient_integer_width){b1[coefficient_width-1]}},
                            b1,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign b2_int         = { {(internal_integer_width-coefficient_integer_width){b2[coefficient_width-1]}},
                            b2,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign a1_int         = { {(internal_integer_width-coefficient_integer_width){a1[coefficient_width-1]}},
                            a1,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign a2_int         = { {(internal_integer_width-coefficient_integer_width){a2[coefficient_width-1]}},
                            a2,
                            {(internal_decimal_width-coefficient_decimal_width){1'b0}} };
  assign gain_int       = { {(internal_integer_width-gain_integer_width){gain[gain_width-1]}},
                            gain,
                            {(internal_decimal_width-gain_decimal_width){1'b0}} }; 
  assign saturation_int = { {(internal_integer_width-inout_integer_width){saturation[inout_width-1]}},
                            saturation,
                            {(internal_decimal_width-inout_decimal_width){1'b0}} };
                            

  /* tvalid, tready management */
  always @(posedge aclk)
    begin
      if (!resetn)
        begin
          m_axis_tvalid <= 1'b0;
          s_axis_tready <= 1'b0;
        end
      else
        begin
         m_axis_tvalid <= s_axis_tvalid;
         s_axis_tready <= m_axis_tready;
        end
    end
  
  /* tlast management */
  always @(posedge aclk)
    begin
      if (!resetn)
        m_axis_tlast <= 1'b0;
      else
        m_axis_tlast <= s_axis_tlast;
    end
      
      


  
  /* pipeline registers */
  always @( posedge aclk or negedge resetn)
     begin
       if (!resetn) 
         begin     
           
           sum22 <= 0;
           sum11 <= 0;
    
         end 
       else 
         begin 
           
           sum22 <= b2_int*input_int - a2_int*output_int;
           sum11 <= b1_int*input_int - a1_int*output_int+sum22;
             
         end   
     end
     

    //assign prodTotal = b0_int*input_int+ sum11;
    
    
    // (right shift + typecast) to scale the output_int into the correct scaling
    //right shift get rid of unwanted underflow
    //typecast get rid of unwanted overflow
    //assign output_int = prodTotal >>> (internal_decimal_width);
    assign output_int = (b0_int*input_int+ sum11) >>> (internal_decimal_width);
    
    assign gainOutputTotal = gain_int*output_int;
    assign gainOutput_int  = gainOutputTotal >>> internal_decimal_width;
    
    //(right shift +typecast)
    //shift extra 1 point to avoid overflow due to the summation.
   
   
    always @ (posedge aclk)
      begin
        if (!resetn || !OnOff ) 
          m_axis_tdata <= s_axis_tdata; 
        else if ( gainOutput_int >= saturation_int)
          m_axis_tdata <= saturation;
        else if ( gainOutput_int <= (-saturation_int))
          m_axis_tdata <= (-saturation);
        else
          m_axis_tdata <= ((gainOutput_int) >>> (internal_decimal_width-inout_decimal_width));
      end
      
endmodule