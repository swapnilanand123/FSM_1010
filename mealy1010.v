// Code your design here
module sequence_detector_overlapping_mealy( clk, rst,data_in,data_out);
input clk;
input rst;
input data_in; 
output reg data_out;

parameter S0 = 2'b00, S1=2'b01, S2=2'b10, S3=2'b11;
reg [1:0]ns,ps;

  always @ (posedge clk,negedge rst)
  begin
    if(!rst)
      ps<=2'b00;
  else
    ps<=ns;
  end
  always@(*)
   
    case(ps)
        S0:begin ns<=data_in?S1:S0;
               data_out<=1'b0;
        end
        S1:begin ns<=data_in?S1:S2;
             data_out<=1'b0; end
        S2: begin ns<=data_in?S3:S0;
              data_out<=1'b0; end
        S3: begin ns<=data_in?S1:S2;
               data_out<= data_in ?0:1;
      end
        default: begin ns<=2'b00;
            data_out<=1'b0;end
      
      endcase    
endmodule
