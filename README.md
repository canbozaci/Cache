# Cache
## L1 Data, L1 Instruction and L2 Unified Cache Design FOR RV64IMC

In the cache design, as specified in the specification, the instruction and data memory is separated at the 1st level, and a unified design has been made at the 2nd level. The block diagram showing the connections of the cache with the memory unit (RAM) located outside the core and the chip and the connections within the cache itself can be seen below. The reset input is not shown in the block diagram due to the large number of cables. Each level cache and controller also have reset inputs. The cache controller was written as a single module in the design, but it is shown here as two modules, because it makes the block diagram more readable.

![q](https://user-images.githubusercontent.com/81713653/185472909-7442a3be-75b6-40bb-a718-2c6bccf4df05.jpg)

<div align="center">
Figure 1: Cache Block Diagram
</div>



In the 1st level cache designs, there is a single address entry since the write and read operations cannot be done from different addresses at the same time. In the 2nd level cache design, there are two write and two read inputs, so there are separate addresses for these ports (2 address entries in total). The reason for choosing two read inputs is to ensure that both level 1 caches can be read simultaneously from level 2 cache without waiting for each other. Even if the 1st level instruction cache will not write directly to the 2nd level cache, if there is a miss situation in the 2nd level cache's instruction read input, there will be a write from the external memory and 2 write entries have been selected since it is possible to perform a write operation from the data cache at the same time. In the 2nd level cache design, being able to read and write from 2 different inputs increased the performance, but made the design process more difficult and increased the space usage. SRAM technology was primarily intended to be used in the design of memory blocks. With the help of SRAM technology, 6 transistors, 2 capacitors and a sense amplifier, a one-bit memory can be created. On the contrary, in registers (D-Flip Flop) made with NAND logic gates, a total of 8 NAND gates are used. Since the NAND gate consists of 4 transistors, there are 32 transistors in total. Although the space usage in the one-bit memory design made with D-FF is higher than that of SRAM technology, it remains much slower in terms of speed compared to the design made with D-FF due to the use of a sense amplifier in SRAM technology. During the design process, it was aimed to create caches in SRAM technology with the help of OpenRAM. Although OpenRAM supports Sky130 technology, caches could not be created with SRAM technology due to errors in synthesis stages and problems in the library files of memory units to be created for multi-input writing/reading purposes. A design made with D-FFs is in focus. In the design made with D-FF, a more flexible design could be made since the memory design was entirely in the hands of the designer. 

In all level caches, 2-level set associativity is preferred in the block placement stage. The most important reasons for this preference are the small size of the cache, the reduction of the miss rate when switching from direct mapped to the 2-level set associative compared to other levels, and minimizing the hit time in caches. The long-term effect of increasing the level of set association on different memory sizes can be seen in Figure 2.


![image](https://user-images.githubusercontent.com/81713653/185473947-39952eec-367d-4cab-931a-a85598cef1fd.png)

Figure 2: Effect of Set Associativity Level on Hit Rate for Different Memory Sizes [1] 



The cache line size has been chosen as 128-bit. For ease of design, the cache line size has been kept the same at all levels. 128-bit selection of line size, 2-bit byte selection, 2-bit word selection (in-block word number), 7-bit tag, and 8-bit index when address range is 19-bit as specified in the 2nd level caches. an addressing has been made. For the 1st level caches, unlike the 2nd level, the index is 6-bit and the tag is 9-bit. The reason for this change is due to the fact that the 1st level caches are 2 KB and the 2nd level cache is 8 KB. Since the set associativity is selected, the tag bits in the accessed index number will be checked in parallel for both sets while performing the block diagnosis. Level 1 cache has 64 blocks for both sets, while level 2 cache has 256 blocks. Associative selection with a 2-level set reduced the miss rate, but required the use of extra space as it required the storage of the tag bits, the use of a replacement algorithm, and the comparison of the stored tag bits with the tag bits at the incoming address. In the replacement phase, the LRU (Least Recently Used) algorithm is used. Since the set associativity level is chosen as 2, the LRU algorithm is implemented with the help of a 64-bit register in the 1st level caches (separately for the instruction and data caches), and with the help of a 256-bit register in the 2nd level cache. While reading from an address in the algorithm, if a hit occurs, the LRU bit of the set with that index is updated. In the case of write, if there are valid bits in both sets of the address to be written, writing is made to the set with the last unread index number. On the other hand, if only one of the sets has a valid bit while writing, the other set will be the one to write. If both have no valid bits (first-time writes), writes are always made to the first set.

In the replacement algorithm, some additions have been made since the core will write to the 1st level data cache. If there is a hit at the address written by the core, the data should be written to the hit set, not to the set selected by the LRU. In the 2nd level cache, some changes have been made in the replacement algorithm because there are 2 read and 2 write entries. If it is desired to read from 2 entries with the same index but different addresses at the same time, the LRU bit in that index is not updated. If the 2 write entries have the same index but want to write to different addresses, the LRU algorithm is ignored and the first and second cluster are written to, respectively.

Write-through was chosen as the writing policy. Although write-through takes longer than later write-back, which is another write policy, such a preference has been made due to the small cache sizes and the fact that peripherals have access to memory. Other factors in choosing a write-through policy are that in the case of a post-write, one dirty bit must be kept for each block, so controlling them increases the latency, and the design of direct-write is simpler than write-back. Write-throughs are only the result of a write operation by the core to the level 1 data cache. This write operation is controlled by the cache controller.

The communication of the cache with the memory unit located outside the chip is provided with the help of the cache controller. Necessary write and read signals are sent to the outside. Since the external memory unit can read and write 32-bit and can only read from one input at a time, if a 128-bit read is to be made, the address is sent and the least meaningless 2nd bit of the address is 1 A row transfer is provided by increasing each. If the core writes to the data cache, the necessary bits of the write_strobe signal in the memory unit are activated according to the size of this write. Since the external memory unit will be 64-bit at most, the write operation is done twice and the least meaningless 2nd bit of the address is incremented by one at the end of the first write operation. If the 2nd level cache misses on both read inputs, the miss problem of the data cache is always taken care of first, then the miss problem of the instruction cache is solved, since a simultaneous write operation can be made from the external memory unit.

In the top-level cache design, the processor waits for the instruction cache read signal and address information by the core, and sends the read data to the core. On the load side of the data cache, in addition to these, the read operation is a byte-addressable data, and additionally asks for information on how to read, and this information is included in the funct3 signal in the 32-bit decoded instruction. For the store side of the data cache, the write signal and the data to be written are expected. As with reading, knowledge of the funct3 signal is required. If it misses any of the caches, this signal is transmitted to the core and the core delays itself until there is a hit signal from the cache.

Since the data always comes to the most meaningless bits in the write operation (storage) coming to the data cache at the 1st level, as a result of decoding the 32-bit instruction, with the help of funct3 bits, the bits coming from the core are shifted as necessary and then the decoded instruction is written as a result. On the read (load) side, the most meaningless bits should always be output.

In the 1st level instruction cache, since compressed (16-bit) and normal (32-bit) instructions coexist, the data to go to the core should be selected accordingly. This selection means that if the last two bits of the data at the given address are "11", it is normal, otherwise it is a compressed instruction. After reading one compressed instruction, the alignment in the cache shifts until another compressed instruction is read, so extra processing is required when reading the instructions. Finally, if the word at the end of the line is wanted to be read after the compressed command is read once, since reading should be done from the address with the next index, the interior design always looks at the data coming from the address with the index. In such a case, if there is a miss at the next address, a write is made here from the higher-level cache. If there is a hit, the output is given data directly and the LRU bit of the set containing the data with the next index is also updated.

## REFERENCES:

1-	Asanovic, K., & Stojanovic, V. (n.d.). Great Ideas in Computer Architecture (Machine Structures) Caches Part 2. Retrieved July 9, 2022, from https://inst.eecs.berkeley.edu/~cs61c/sp15/lec/15/2015Sp-CS61C-L15-kavs-Caches2-6up.pdf


