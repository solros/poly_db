compare_output { print write_json(load('1.poly')) } '1' 
	and
compare_output { print write_json(load('2.poly')) } '2' 
	and
compare_output { print write_json(load('3.poly')) } '3'
	and
compare_output { print write_json(load('4.poly')) } '4' ;
