compare_values( '3dim', 18, poly_db_count({"CONE_DIM"=>4}, db=>"LatticePolytopes", collection=>"SmoothReflexive") )
	and
compare_values( '8dim', 749892, poly_db_count({"CONE_DIM"=>9}, db=>"LatticePolytopes", collection=>"SmoothReflexive") )
	and
compare_values( '1', 97595, poly_db_count({"N_VERTICES" => { '$lt' => 100, '$gt' => 50 }}, db=>"LatticePolytopes", collection=>"SmoothReflexive") );
;
