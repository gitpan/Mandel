package Mandel::Relationship;

=head1 NAME

Mandel::Relationship - Base class for relationships

=head1 DESCRIPTION

=over 4

=item * L<Mandel::Relationship::HasMany>

=item * L<Mandel::Relationship::HasOne>

=back

=cut

use Mojo::Base -base;
use Mojo::Loader;

my $LOADER = Mojo::Loader->new;

sub _load_class {
  my $class = pop;
  my $e = $LOADER->load($class);
  die $e if ref $e;
  $class;
}

sub _foreign_key {
  sprintf '_id_%s', $_[1]->model->name;
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;