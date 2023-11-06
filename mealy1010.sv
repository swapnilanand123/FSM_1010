`timescale 1ns/1ns

class transaction;
  rand bit data_in;
  bit data_out;

  function void display(input string tag);
    $display("[%0s] : DATAIN: %0b DATAOUT: %0b @ %0t", tag, data_in, data_out, $time);
  endfunction

  function transaction copy();

    copy = new();
    copy.data_in = this.data_in;
    copy.data_out = this.data_out;
    return copy;
  endfunction
endclass

class generator;
  transaction tr;
  mailbox #(transaction) mbx;
  int count = 0;
  event next;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
  endfunction;

  task run();
    for (int i = 0; i < count; i++) begin
      assert(tr.randomize) else $error("Randomization failed");
      mbx.put(tr.copy);
      tr.display("GEN");
      ->next;
    end
  endtask
endclass

class driver;
  virtual mealy1010_if fif;
  mailbox #(transaction) mbx;
  transaction datac;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction;

  task reset();
    fif.rst <= 1'b1;
    fif.data_in <= 0;
    repeat(5) @(posedge fif.clk);
    fif.rst <= 1'b0;
    $display("[DRV] : DUT Reset Done");
  endtask

  task run();
    forever begin
      mbx.get(datac);
      datac.display("DRV");
      fif.data_in <= datac.data_in;
      repeat(2) @(posedge fif.clk);
     // ->next;
    end
  endtask
endclass

class monitor;
  virtual mealy1010_if fif;
  mailbox #(transaction) mbx;
  transaction tr;

  function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
  endfunction;

  task run();
    tr = new();
    forever begin
      repeat(2) @(posedge fif.clk);
      tr.data_in = fif.data_in;
      tr.data_out = fif.data_out;
      mbx.put(tr);
      tr.display("MON");
    end
  endtask
endclass

class scoreboard;
  mailbox #(transaction) mbx;
  int num_transactions;
  int transactions_received;
  event next;

  function new(mailbox #(transaction) mbx, int num_transactions);
    this.mbx = mbx;
    this.num_transactions = num_transactions;
    transactions_received = 0;
  endfunction;

  task run();
    transaction tr;
    repeat (num_transactions) begin
      mbx.get(tr);
      tr.display("SCO");

      // Check the received data against expected values and perform necessary checks.
      if (tr.data_out == 1'b1) begin
        $display("[SCO] : Successful Output");
        if (tr.data_in == 2'b00) begin
          $display("[SCO] : Start of the sequence");
        end
      end else if (tr.data_in == 2'b01) begin
        $display("[SCO] : Still searching for the sequence");
      end else if (tr.data_in == 2'b10) begin
        $display("[SCO] : Still searching for the sequence");
      end else begin
        $display("[SCO] : Sequence detected");
      end

      transactions_received++;
      if (transactions_received == num_transactions)
        ->next;
    end
  endtask
endclass

class environment;
  generator gen;
  driver drv;
  monitor mon;
  scoreboard sco;
  mailbox #(transaction) gdmbx;
  mailbox #(transaction) msmbx;
  event next;

  function new(virtual mealy1010_if fif);
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);
    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx, 20); // Provide a default value for "num_transactions"
    drv.fif = fif;
    mon.fif = fif;
    gen.next = next;
    sco.next = next;
  endfunction

  task pre_test();
    drv.reset();
  endtask

  task test();
    fork
      gen.run();
      drv.run();
      mon.run();
      sco.run();
    join_any
  endtask

  task post_test();
    wait(sco.transactions_received == sco.num_transactions);
    $finish();
  endtask

  task run();
    pre_test();
    test();
    post_test();
  endtask
endclass

module tb;
  mealy1010_if fif();
  mealy1010 dut (fif.clk, fif.rst, fif.data_in, fif.data_out);

  initial begin
    fif.clk <= 0;
  end

  always #10 fif.clk <= ~fif.clk;

  environment env;

  initial begin
    env = new(fif);
    env.gen.count = 20;
    env.run();
  end

  initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
  end
endmodule
