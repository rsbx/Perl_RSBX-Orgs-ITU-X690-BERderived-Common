#  Copyright (c) 2016, Raymond S Brand
#  All rights reserved.
#
#  Redistribution and use in source and binary forms, with or without
#  modification, are permitted provided that the following conditions
#  are met:
#
#   * Redistributions of source code must retain the above copyright
#     notice, this list of conditions and the following disclaimer.
#
#   * Redistributions in binary form must reproduce the above copyright
#     notice, this list of conditions and the following disclaimer in
#     the documentation and/or other materials provided with the
#     distribution.
#
#   * Redistributions in source or binary form must carry prominent
#     notices of any modifications.
#
#   * Neither the name of Raymond S Brand nor the names of its other
#     contributors may be used to endorse or promote products derived
#     from this software without specific prior written permission.
#
#  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
#  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
#  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
#  FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
#  COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
#  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
#  BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
#  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
#  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
#  ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
#  POSSIBILITY OF SUCH DAMAGE.


package RSBX::Orgs::ITU::X690::BERderived::Common v0.1.0.0;


use strict;
use warnings;


require Exporter;
our @ISA = qw(Exporter);
our %EXPORT_TAGS = ( );
our @EXPORT_OK = qw( ObjectHeaderValidate ObjectHeaderDecode );
our @EXPORT = qw( );


sub ObjectHeaderValidate
	{
	my ($pdu_ref, $pdu_start, $pdu_end) = @_;

	my $pdu_len = $pdu_end-$pdu_start;
	my $ref_len = length(${$pdu_ref});

	if ($pdu_start < 0 || $pdu_start > $pdu_end || $pdu_end > $ref_len)
		{
		return -1;
		}

	if ($pdu_len < 2)
		{
		return 2 - $pdu_len;
		}

	my $identifier_octet = unpack("C", substr(${$pdu_ref}, $pdu_start, 1));
#	my $class = ($identifier_octet & 0xc0) >> 6;
	my $constructed_flag = ($identifier_octet & 0x20) >> 5;
	my $tag_number = $identifier_octet & 0x1f;
	my $tag_length = undef;

	if ($tag_number != 0x1f)			# Short form
		{
		$tag_length = 1;
		}
	else						# Long form
		{
		my $i = 1;
		my $need;

		if ((unpack("C", substr(${$pdu_ref}, $pdu_start+$i, 1)) & 0x80) == 0x80)	# Illegal
			{
			return -1;
			}
		while ($i < $pdu_len && ($need = unpack("C", substr(${$pdu_ref}, $pdu_start+$i, 1)) & 0x80))
			{
			$i++;
			}
		if ($need)
			{
			return 2;
			}
		$tag_length = $i+1;
		}

	if ($tag_length == $pdu_len)
		{
		return 1;
		}

	my $length_length = unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length, 1));
	if (!($length_length & 0x80))	# Short form
		{
		return 0;
		}

	if ($length_length == 0x80)	# Indefinite form
		{
		return $constructed_flag ? 0 : -1;
		}

	if ($length_length == 0xff)	# Future extension
		{
		return -1;
		}

	$length_length = ($length_length &= 0x7f) + 1;

	if ($pdu_len < $tag_length + $length_length)
		{
		return $tag_length + $length_length - $pdu_len;
		}

	return 0;
	}


sub ObjectHeaderDecode
	{
	my ($pdu_ref, $pdu_start, $pdu_end) = @_;

	if (ObjectHeaderValidate($pdu_ref, $pdu_start, $pdu_end) != 0)
		{
		return undef;
		}

	my $identifier_octet = unpack("C", substr(${$pdu_ref}, $pdu_start, 1));
	my $class = ($identifier_octet & 0xc0) >> 6;
	my $constructed_flag = ($identifier_octet & 0x20) >> 5;
	my $tag_number = $identifier_octet & 0x1f;
	my $tag_length = undef;

	if ($tag_number != 0x1f)			# Short form
		{
		$tag_length = 1;
		}
	else						# Long form
		{
		my $i = 1;

		while (unpack("C", substr(${$pdu_ref}, $pdu_start+$i, 1)) & 0x80)
			{
			$i++;
			}
		$tag_length = $i+1;
		}

	my $length_length = 1;
	my $content_length = 0;

	if (!(unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length, 1)) & 0x80))
		{
		$content_length = unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length, 1)) & 0x7f;
		}
	elsif (unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length, 1)) == 0x80)
		{
		$content_length = -1;
		}
	else
		{
		$length_length = 1 + unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length, 1)) & 0x7f;
		}

	if ($tag_length > 5 || $length_length > 4)
		{
		return ($class, ($tag_length>5) ? -1 : $tag_number, $constructed_flag, $tag_length, $length_length, ($length_length>4) ? -1 : $content_length);
		}

	if ($tag_length != 1)
		{
		$tag_number = 0;
		my $i = 1;
		while ($i < $tag_length)
			{
			$tag_number = ($tag_number << 7) + unpack("C", substr(${$pdu_ref}, $pdu_start+$i, 1)) & 0x7f;
			$i++;
			}
		}

	if ($length_length > 1)
		{
		for (my $i = 1; $i < $length_length; $i++)
			{
			$content_length = ($content_length << 8) + unpack("C", substr(${$pdu_ref}, $pdu_start+$tag_length+$i, 1));
			}
		}

	return ($class, $tag_number, $constructed_flag, $tag_length, $length_length, $content_length);
	}


1;


__END__


=pod

=head1 NAME

RSBX::Orgs::ITU::X690::BERderived::Common - Common functions for inspecting BERderived object type encodings.

=head1 SYNOPSIS

 use RSBX::Orgs::ITU::X690::BERderived::Common;

 if (ObjectHeaderValidate(\$data, 0, length($data)) < 0)
     {
     die;
     }

 my ($class, $tag_number,
         $constructed_flag, $tag_length,
         $length_length, $content_length)
         = ObjectHeaderDecode(\$data, 0, length($data));
 die() if ! defined($class);

=head1 DESCRIPTION

Common functions for inspecting BERderived encodings.

=head1 FUNCTIONS

=over 4

=item ObjectHeaderValidate( I<data_REF>, I<start_offset>, I<end_offset> )

Checks if a sequence of bytes is a valid BERderived object type header encoding.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<data_REF>

Reference to the buffer (string) containing the encoding to validate.

=item I<start_offset>

Offset into the data buffer where the encoding to validate begins.

=item I<end_offset>

Offset into the data buffer where the encoding to validate ends.
The length of the encoding to validate is C<I<end_offset> - I<start_offset>>.

=back

=back

=item RETURNS

=over 4

=over 4

=item integer status

=over 4

=item C<0>

The entire object header is available and validates.

=item C<-1>

The data is not a valid BER derived object type header encoding or
C<I<start_offset> E<gt> I<end_offset>>.

=item C<E<gt> 0>

The minimum number of additional bytes required for a valid BER derived object
type header encoding. More than this number may be required so the data should
be re-validated after the additional bytes are added.
See L<ITU-T Rec. X.690|/SEE ALSO> for specifics.

=back

=back

=back

=back

=item ObjectHeaderDecode( I<data_REF>, I<start_offset>, I<end_offset> )

Decodes a BERderived object type header in its component parts.

=over 4

=item PARAMETERS

=over 4

=over 4

=item I<data_REF>

Reference to the buffer (string) containing the encoding to validate.

=item I<start_offset>

Offset into the data buffer where the encoding to validate begins.

=item I<end_offset>

Offset into the data buffer where the encoding to validate ends.
The length of the encoding to validate is C<I<end_offset> - I<start_offset>>.

=back

=back

=item RETURNS

An I<ARRAY> containing:

=over 4

=over 4

=item class_number

The class number of the object, see L<ITU-T Rec. X.690|/SEE ALSO> for
specifics, or C<undef> if the object header could not be decoded.

=item tag_number

The tag number of the object, see L<ITU-T Rec. X.690|/SEE ALSO> for
specifics, or C<-1> if the object tag number is too large for this implementation.

=item constructed_flag

Will be I<true> of the object is not I<primative>.  See
L<ITU-T Rec. X.690|/SEE ALSO> for specifics.

=item tag_length

The length of the I<tag> information in the object header.
See L<ITU-T Rec. X.690|/SEE ALSO> for specifics.

=item length_length

The length of the object content length information in the object header.
See L<ITU-T Rec. X.690|/SEE ALSO> for specifics.

=item content_length

The length of the object content or C<-1> if the object was encoded using the
I<indefinite form> (see L<ITU-T Rec. X.690|/SEE ALSO> for specifics) or the
content length is too large for this implementation.

The object was encoded using the I<indefinite form> IFF C<I<length_length> == 1 AND I<content_length> == -1>.

=back

=back

=back

=back

=head1 BUGS AND LIMITATIONS

=over 4

=item * Almost no parameter validation is performed. Code wisely.

=back

Please report problems to Raymond S Brand E<lt>rsbx@acm.orgE<gt>.

Problem reports without included demonstration code and/or tests will be ignored.

Patches are welcome.

=head1 SEE ALSO

L<ITU-T Rec. X.690|https://en.wikipedia.org/wiki/X.690>,
L<ITU-T Rec. X.680|https://en.wikipedia.org/wiki/Abstract_Syntax_Notation_One>

=head1 AUTHOR

Raymond S Brand E<lt>rsbx@acm.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2016 Raymond S Brand. All rights reserved.

=head1 LICENSE

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:

=over 4

=item *

Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.

=item *

Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in
the documentation and/or other materials provided with the
distribution.

=item *

Redistributions in source or binary form must carry prominent
notices of any modifications.

=item *

Neither the name of Raymond S Brand nor the names of its other
contributors may be used to endorse or promote products derived
from this software without specific prior written permission.

=back

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

=cut

