

package PolyDB::Shell;

sub poly_db_tab_completion {
	my $line = shift;
	if ($line =~m{db\s*=>\s*$}xo) {
		return common::get_db_list();
	}
	return 0;
}

1;
