package Mandel::Model;

=head1 NAME

Mandel::Model - An object modelling a document

=head1 DESCRIPTION

This class is used to descrieb the structure of L<document|Mandel::Document>
in mongodb.

=cut

use Mojo::Base -base;
use Mojo::Loader;
use Mojo::Util;
use Carp 'confess';

my $LOADER = Mojo::Loader->new;
my $ANON = 1;

=head1 ATTRIBUTES

=head2 collection_name

The name of the collection in the database. Default is the plural form of L</name>.

=head2 collection_class

The class name of the collection class. This default to L<Mandel::Collection>.

=head2 document_class

The class name of the document this description is attached to. Default to
an autogenerated class name.

=head2 name

The name of this model. Same as given to L<Mandel/model> and
L<Mandel/collection>.

=cut

has collection_name => sub {
  my $self = shift;
  my $name = $self->name;

  return $name =~ /s$/ ? $name : $name .'s' if $name;
  confess "collection_name or name required in constructor";
};

has collection_class => 'Mandel::Collection';

has document_class => sub {
  my $self = shift;
  my $name = ucfirst $self->name || 'AnonDoc';
  my $class = "Mandel::Document::__ANON_${ANON}__::$name"; # this might change

  eval <<"  PACKAGE" or confess $@;
  package $class;
  use Mojo::Base "Mandel::Document";
  sub model { \$self }
  \$INC{"Mandel/Document/__ANON__$ANON.pm"} = "GENERATED";
  PACKAGE

  $ANON++;
  $class;
};

has name => '';

=head1 METHODS

=head2 field

  $self = $self->field('name', %args);
  $self = $self->field(['name1', 'name2'], %args);

Used to define new field(s) to the document.

=cut

sub field {
  my($self, $fields, %args) = @_;
  my $class = $self->document_class;

  # Compile fieldibutes
  for my $field (@{ ref $fields eq 'ARRAY' ? $fields : [$fields] }) {
    my $code = "";

    $code .= "package $class;\nsub $field {\n my \$raw = \$_[0]->data;\n";
    $code .= "return \$raw->{'$field'} if \@_ == 1;\n";
    $code .= "local \$_ = \$_[1];\n";
    $code .= $self->_field_type($args{isa}) if $args{isa};
    $code .= "\$_[0]->{dirty}{$field} = 1;";
    $code .= "\$raw->{'$field'} = \$_;\n";
    $code .= "return \$_[0];\n}";

    # We compile custom attribute code for speed
    no strict 'refs';
    warn "-- Attribute $field in $class\n$code\n\n" if $ENV{MOJO_BASE_DEBUG};
    Carp::croak "Mandel::Document error: $@" unless eval "$code;1";
  }

  $self;
}

sub _field_type {
  my($self, $type) = @_;
  my $code = "";

  use Types::Standard qw( Num );

  if($type->can_be_inlined) {
    $code .= $type->inline_assert('$_');
  }
  if($type->is_a_type_of(Num)) {
    $code .= "\$_ += 0;\n";
  }

  return $code;
}

=head2 relationship

  $rel_obj = $self->relationship($type => $field_name => 'Other::Document::Class');
  $rel_obj = $self->relationship($field_name);

This method is used to describe a relationship between two documents.

See L<Mandel::Relationship::BelongsTo>, L<Mandel::Relationship::HasMany> or
L<Mandel::Relationship::HasOne>.

=cut

sub relationship {
  my $self = shift;

  if(@_ == 1) {
    return $self->{relationship}{$_[0]};
  }

  my($type, $field, $other, %args) = @_;
  my $class = 'Mandel::Relationship::' .Mojo::Util::camelize($type);
  my $e = $LOADER->load($class);

  confess $e if ref $e;

  $self->{relationship}{$field}
    = $class->new(
        accessor => $field,
        document_class => $self->document_class,
        related_class => $other,
        %args,
      );
}

=head2 new_collection

  $self->new_collection($connection);

Returns a new instance of L</collection_class>.

=cut

sub new_collection {
  my($self, $connection, %args) = @_;

  $self->collection_class->new({
    connection => $connection || confess('$model->new_collection($connection)'),
    model => $self,
    %args,
  });
}

=head1 SEE ALSO

L<Mojolicious>, L<Mango>, L<Mandel>

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
