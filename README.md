# AXI4-Stream Interconnect FIFO

This AXI4-Stream Interconnect FIFO IP manages traffic on AXI4-Stream interfaces where it allows multiple AXI masters connect to multiple AXI slaves. It uses the TDEST signal to
route masters to slaves. This IP Core uses a MSB-LSB alternating priority selector for its arbitration logic when multiple slaves are writing into one slave. Each slave has one FIFO buffer
while slave port read from for data in queue writing to the slave, backpressuring logic is implemented as well in the FIFO. 

Note: Slave Interfaces in this context refers to the input interface of the interconnect (connected to the master ports, Master Interface refers to the output interface (connected to the slave ports)

Features:
- Parameterizable number of master and slave connections
- TDEST decoding for master to slave connections
- FIFO buffer for each slave port connections
- MSB-LSB Alternating Arbitration scheme to determine priority if multiple master is writing to a slave in one cycle

## Testing
Currently Still in Progress

Tested Features: Arbitration Logic, FIFO, Index Encoding, Routing Logic, Slave Read from full FIFO

To Be Tested: FIFO Backpressuring, Multiple Master Writes, Multiple Slave Reads

## Next Steps

- Full Test the IP
- Multiple Arbitration scheme which designers can choose from
- Implement TSTRB, TKEEP signals
- Implement full AXI4-MM protocol interconnect
