=head1 OpenXPKI::Client::Config

This is a helper package for all cgi based client interfaces to read a 
client config file base on the name of the script called. It was designed
to work inside an apache server but should do in other environments as 
long as the environment variables are available or adjusted.

=head2 Environment variables

=over 

=item OPENXPKI_CLIENT_CONF_DIR

The path of the OpenXPKI base config directory, default I</etc/openxpki>

=item OPENXPKI_I<SERVICE>_CLIENT_CONF_DIR

I<SERVICE> is the name of the service as given to the constructor.
The default value is the basedir plus the name of the service, e.g.
I</etc/openxpki/scep>. This is the base directory where the service
config is initialized from the file I<default.conf>. If you use 
the config autodiscovery feature (config name from script name), those
files need to be here, too.

It is B<not> used if an expicit config file is set with 
OPENXPKI_I<SERVICE>_CLIENT_CONF_FILE!

=item OPENXPKI_I<SERVICE>_CLIENT_CONF_FILE  

=back

=head2 Default Configuration

Mostly logger config, used before FCGI is spawned and if no special 
config is found.

=head2 Entity Configuration / Autodiscovery

Most cgi wrappers offer autodiscovery of config files based on the 
scripts filename, which is espacially handy with rewrite or alias rules.
E.g. with the default scep configuration you can use 
http://servername/scep/my-endpoint in your scep client which will load
the entity configuration from the file I<my-endpoint.conf> in the scep
config directory (by default /etc/openxpki/scep, see also notes above).

If no such file is found, the default configuration is used.

=cut

package OpenXPKI::Client::Config;

use Moose;
use File::Spec;
use Log::Log4perl qw(:easy);
use Data::Dumper;
use Config::Std;

has 'service' => (
    required => 1,    
    is => 'ro',
    isa => 'Str',    
);

# the service specific path
has 'basepath' => (
    required => 0,
    is => 'ro',
    isa => 'Str',
    lazy => 1,
    builder => '__init_basepath'
);

has 'default' => (
    required => 0,
    is => 'rw',
    isa => 'HashRef',   
    lazy => 1,
    builder => '__init_default',
);


has 'configfile' => (
    required => 0,
    is => 'rw',
    isa => 'Str',
    lazy => 1,
    builder => '__init_configfile',
);

has 'config' => (
    required => 0,
    is => 'ro',
    isa => 'HashRef',
    lazy => 1,
    builder => '__init_config',
);

has 'logger' => (
    required => 0,
    lazy => 1,
    is => 'rw',
    isa => 'Object',
    builder => '__init_logger',    
);

# this allows a constructor with the service as scalar
around BUILDARGS => sub {

    my $orig = shift;
    my $class = shift;
  
    my $args = shift;
    if (!ref $args) {
        $args = { service => $args };
    }
    return $class->$orig( $args );

};

sub BUILD {
    
    my $self = shift;
    
    if ($self->service() !~ /\A[a-zA-Z0-9]+\z/) {
        die "Invalid service name: " . $self->service();
    }
    
    my $config = $self->default();
    
    $self->logger()->debug(sprintf('Config for service %s loaded', $self->service()));
    $self->logger()->trace('Global config: ' . Dumper $config );
    
}
    
sub __init_basepath {
    
    my $self = shift;
    
    # generate name of the environemnt values from the service name        
    my $env_dir = 'OPENXPKI_'.uc($self->service()).'_CLIENT_CONF_DIR';
    
    # check for service specific basedir in env
    if ( $ENV{$env_dir} ) {
        -d $ENV{$env_dir}
        || die sprintf "Explicit config directory not found (%s, from env %s)", $ENV{$env_dir}, $env_dir;
                
        return File::Spec->canonpath( $ENV{$env_dir} );
    } 
    
    my $path;
    # check for a customized global base dir
    if ($ENV{OPENXPKI_CLIENT_CONF_DIR}) {
        $path = $ENV{OPENXPKI_CLIENT_CONF_DIR};
        if (!-d $path) {
            die "Explicit client config path does not exists! ($path)";
        }
        $path = File::Spec->canonpath( $path );
    } else {
        $path = '/etc/openxpki';
    }

    # default basedir is global path + servicename
    return File::Spec->catdir( ( $path, $self->service() ) );            
    
}

sub __init_default {
    
    my $self = shift;
    # in case an explicit script name is set, we do NOT use the default.conf
    my $service = $self->service();
    my $env_file = 'OPENXPKI_'.uc($service).'_CLIENT_CONF_FILE';
    
    my $configfile;
    if ($ENV{$env_file}) {
        -f $ENV{$env_file}
            || die sprintf "Explicit config file not found (%s, from env %s)", $ENV{$env_file}, $env_file;
            
        $configfile = $ENV{$env_file};        
        $self->configfile('');
    } else {
        $configfile = File::Spec->catfile( ( ($self->basepath), 'default.conf' ) );        
    }
    
    my $config;
    if (!read_config $configfile => $config) {
        die "Could not read client config file " . $self->configfile() ;
    }
    
    # cast to an unblessed hash 
    my %config = %{$config};
    return \%config;
    
}
    
sub __init_configfile() {    
    
    my $self = shift;
       
    my $configfile = '';
    # generate name of the environemnt values from the service name    
    my $service = $self->service();
       
    # Test for specific config file based on script name
    # SCRIPT_URL is only available with mod_rewrite
    my $file;
    if (defined $ENV{SCRIPT_URL}) {
        $ENV{SCRIPT_URL} =~ qq|${service}/([^/]+)(/[^/]*)?\$|;
        $file = "$1.conf";

    # Should always work
    } elsif (defined $ENV{REQUEST_URI}) {
        $ENV{REQUEST_URI} =~ qq|${service}/([^/\?]+)(/[^/\\?]*)?(\\?.*)?\$|;
        $file = "$1.conf";

    # Hopefully never seen
    } else {
        warn "Unable to detect script name - please check the docs";
        warn Dumper \%ENV;
    }
   
    if ($file) {
        $self->logger()->debug('Autodetect config file for service ' . $service . ': ' . $file );       
        $file = File::Spec->catfile( ($self->basepath() ), $file );
        if (! -f $file ) {
            $self->logger()->debug('No config file found, falling back to default');
        } else {
            $configfile = $file;    
        }
    }
    return $configfile;    
}

sub __init_config {
    
    my $self = shift;

    my $configfile = $self->configfile();
    
    # if no config file is given, use the default
    if (!$configfile) {
        $self->logger()->debug('No special config file - use default settings.');
        return $self->default();
    }

    my $config;
    if (!read_config $configfile => $config) {
        $self->logger()->error('Unable to read config from file ' . $configfile);
        die "Could not read client config file $configfile ";
    }
    
    # cast to an unblessed hash 
    my %config = %{$config};
    
    $self->logger()->trace('Script config: ' . Dumper \%config );
    
    return \%config;
}

sub __init_logger {
    
    my $self = shift;
    my $config = $self->default();
        
    my $logger; 
    my $log_config = $config->{global}->{log_config};    
    if ($log_config) {
        Log::Log4perl->init_once($log_config);        
        my $facility = $config->{global}->{log_facility} || '';
        $logger = Log::Log4perl->get_logger($facility);
        $logger->debug('Starting logger from config with config '.$log_config.', facility ' . $facility);                
    } else {
        Log::Log4perl->easy_init();
        $logger = Log::Log4perl->get_logger();        
    }
            
    $self->logger( $logger );
}

1;

__END__;
