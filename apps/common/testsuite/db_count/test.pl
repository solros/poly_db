compare_values( '3dim', 18, db_count({"DIM"=>3}, db=>"LatticePolytopes", collection=>"SmoothReflexive") );
compare_values( '6dim', 866, db_count({"DIM"=>5}, db=>"LatticePolytopes", collection=>"SmoothReflexive") );
compare_values( '1', 9, db_count({"N_VERTICES" => { '$lt' => 100, '$gt' => 50 }}, db=>"LatticePolytopes", collection=>"SmoothReflexive") );
