# Unix *top* command custom implementation: *mitop.sh* 

## Table of contents

* [General Info](#general-info)
* [Technologies](#technologies)
* [Setup](#setup)
* [Copyright](#copyright)
* [References](#references)

## General Info
*top* is a task manager program found in many Unix-like operating systems that displays information about CPU and memory utilization.

This shell script tries to emulate it, showing on screen stadistic information regarding system processes. These processes are top-down ordered with the CPU usage ratio, only showing top 'n' ones. If not specified, 'n' is set to 10. If specified value of 'n' is greater than the number of processes, then information about all of them are shown.

For more info:
- [Task Definition.pdf](https://github.com/misrraimsp/mitop/blob/master/Task%20Definition.pdf)
- [Final Report.pdf](https://github.com/misrraimsp/mitop/blob/master/Final%20Report.pdf)

## Technologies
Project is created with:
* Bash
* Notepad++
* Git
	
## Setup
To run this project, open a linux terminal and write:

```
$ cd ../user/shell
$ mitop n
```
## Copyright

- **year**: 2016
- **script name**:   	 mitop.sh
- **author**:       	 MISRRAIM SUÁREZ PÉREZ
- **mail**:        	 misrraimsp@gmail.com
- **last version**:    30/11/2016

## References
- [Learning the bash Shell, 3rd Edition. Cameron Newham](https://www.oreilly.com/library/view/learning-the-bash/0596009658/)
- [proc(5) — Linux manual page](https://man7.org/linux/man-pages/man5/proc.5.html)



