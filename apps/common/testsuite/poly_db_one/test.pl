compare_object('1.poly', poly_db_one({"_id"=>"F.6D.0000"}, db=>"LatticePolytopes", collection=>"SmoothReflexive") )
	and
compare_object('2.poly', poly_db_one({"_id"=>"F.8D.000000"}, db=>"LatticePolytopes", collection=>"SmoothReflexive") )
	and
compare_object('3.poly', poly_db_one({"CONE_DIM"=>5, "N_VERTICES"=>23}, db=>"LatticePolytopes", collection=>"SmoothReflexive") );
;
