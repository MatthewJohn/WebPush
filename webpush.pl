#!/usr/bin/perl

# This is the source for webpush client application
# This can be compiled using pp

use strict;
use warnings;
use Text::FormatTable;
use Term::ANSIColor;
use Data::Dumper;


my $SERVER = 'localhost';
my $REMOTE_USER = 'root';
my $COMMAND = lc($ARGV[0]);
my $TEMPLATE_FILE = '/root/apachetemplate';
my $TEMPLATE_TEMP_VALUE = 'WEBPUSH_APP_NAME';
my $SITES_AVAILABLE_DIR = '/etc/apache2/sites-available';
my $SITES_ENABLED_DIR = '/etc/apache2/sites-enabled';
my $APP_BASE_DIR = '/var/www';

main();

sub check_dependencies
{
  # This will need to check depencies for this app
  # The following packages must be installed:
    # libtext-formattable-perl

  # This won't be implemented, but for now is a good
  # place to store requisites
}

sub check_authentication
{
  my %authentication_status = run_command('exit');
  if ($authentication_status{'exit_code'})
  {
    die("ERROR: You cannot authenticate with the remote server\n");
  }
}

sub run_command
{
  my $command = shift;
  my $command_output = `ssh -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' $REMOTE_USER\@$SERVER $command`;
  my $exit_code = $?;
  my %return_hash;
  $return_hash{'exit_code'} = $exit_code;
  $return_hash{'output'} = $command_output;
  return %return_hash;
}

sub restart_apache
{
  my %output = run_command('service apache2 reload');
  if ($output{'exit_code'})
  {
    style_text("An error occured whilst restarting the web server", 'RED');
  }
}

sub get_app_repo_type
{
  my $app_name = shift;
  if (check_app_exists($app_name))
  {
    my $repo_type = 0;
    my %git_output = run_command("ls $APP_BASE_DIR/$app_name/.git");
    my %svn_output = run_command("ls $APP_BASE_DIR/$app_name/.svn");
    if (!$git_output{'exit_code'})
    {
      $repo_type = 1;
    }
    elsif (!$svn_output{'exit_code'})
    {
      $repo_type = 2;
    }
    return $repo_type;
  }
  else
  {
    style_text("ERROR: $app_name does not exist", 'RED');
  }
}

sub get_all_running
{
  # Get array of running apps
  my %running_apps = run_command("ls -1 $SITES_ENABLED_DIR/");
  my @running_apps = split(/\n/, $running_apps{'output'});
}

sub get_all_apps
{
  # Get array of all apps
  my %all_apps = run_command("ls -1 $SITES_AVAILABLE_DIR/");
  my @all_apps = split(/\n/, $all_apps{'output'});
  return @all_apps;
}

sub get_all_status
{
  # Get array of all apps
  my @all_apps = get_all_apps();
  my @running_apps = get_all_running();
  my %app_hash;

  foreach my $app (@all_apps)
  {
    # Set default status to stopped
    my $status = 0;
    my $running_name;

    # Make exception for default case, where sites-enabled name
    # is different to sites-available
    if ($app eq 'default')
    {
      $running_name = '000-default';
    }
    else
    {
      $running_name = $app;
    }

    # Check if app exists in running_apps array, if so,
    # set status to running
    if (grep {$_ eq $running_name} @running_apps)
    {
      $status = 1;
    }
    $app_hash{$app} = $status;
  }
  return %app_hash;
}

sub print_all_status
{
  # Create output table
  my $table = Text::FormatTable->new('r|l');
  $table->head
  (
    'Name',
    'Status'
  );
  $table->rule('-');

  my %apps = get_all_status();

  foreach my $app (sort keys %apps)
  {
    my $status_name;
    # Check if app exists in running_apps array, if so,
    # set status to running
    if ($apps{$app})
    {
      $status_name = 'Running';
    }
    else
    {
      $status_name = 'Stopped';
    }
    $table->row($app, $status_name);
  }
  print $table->render(60) . "\n";
}

sub get_title
{
  style_text("Dock Studios WebPush\n", 'GREEN BOLD');
}

sub basic_help
{
  style_text("ERROR: No command was specified\n", 'RED');
  print "For more help, run 'webpush help'\n";
}

sub get_app_status
{
  my $app_name = shift;
  my %all_apps = get_all_status();
  return $all_apps{$app_name};
}

sub check_app_exists
{
  my $app_name = shift;
  my @all_apps = get_all_apps();
  my $exists = 0;
  if (grep {$_ eq $app_name} @all_apps)
  {
    $exists = 1;
  }
  return $exists;
}

sub stop_app
{
  my $app_name = shift;
  if (!check_app_exists($app_name))
  {
    style_text("ERROR: $app_name does not exist\n", 'RED');
  }
  elsif (!get_app_status($app_name))
  {
    style_text("ERROR: $app_name is already stopped\n", 'RED');
  }
  else
  {
    my %stop_command = run_command("a2dissite $app_name");
    if ($stop_command{'exit_code'})
    {
      style_text("ERROR: An error occured whilst stopping $app_name:\n", 'RED');
      print $stop_command{'output'};
    }
    else
    {
      restart_apache();
      style_text("SUCCESS: $app_name has been stopped\n", 'GREEN');
    }
  }
}

sub start_app
{
  my $app_name = shift;
  if (!check_app_exists($app_name))
  {
    style_text("ERROR: $app_name does not exist\n", 'RED');
  }
  elsif (get_app_status($app_name))
  {
    style_text("ERROR: $app_name is already running\n", 'RED');
  }
  else
  {
    my %start_command = run_command("a2ensite $app_name");
    if ($start_command{'exit_code'})
    {
      style_text("ERROR: An error occured whilst starting $app_name:\n", 'RED');
      print $start_command{'output'};
    }
    else
    {
      restart_apache();
      style_text("SUCCESS: $app_name has been started\n", 'GREEN');
    }
  }
}

sub style_text
{
  my ($text, $style) = @_;
  print color "$style";
  print "$text";
  print color 'RESET';
}

sub create_app
{
  my $app_name = shift;
  my $config_file = "$SITES_AVAILABLE_DIR/$app_name";
  if (check_app_exists($app_name))
  {
    style_text("ERROR: App already exists\n", 'RED');
  }
  else
  {
    my %create_config = run_command("cp $TEMPLATE_FILE $config_file");
    run_command("sed -i 's/$TEMPLATE_TEMP_VALUE/$app_name/g' $config_file");
    my %create_dir = run_command("mkdir $APP_BASE_DIR/$app_name");
    style_text("SUCCESS: Created app $app_name\n", 'GREEN');
  }
}

sub delete_app
{
  my $app_name = shift();
  if (!check_app_exists($app_name))
  {
    style_text("ERROR: $app_name does not exist\n", 'RED');
  }
  else
  {
    if (get_app_status($app_name))
    {
      stop_app($app_name);
    }
    my $config_file = "$SITES_AVAILABLE_DIR/$app_name";
    my $app_dir = "$APP_BASE_DIR/$app_name";
    my %remove_config_output = run_command("rm $config_file");
    if ($remove_config_output{'exit_code'})
    {
      style_text("ERROR: Could not remove config file", 'RED');
      die($remove_config_output{'output'});
    }
    my %remove_app_output = run_command("rm -rf $app_dir");
    if ($remove_app_output{'exit_code'})
    {  
      style_text("ERROR: Could not remove app directory", 'RED');
      die($remove_app_output{'output'});
    }
    style_text("SUCCESS: Removed $app_name\n", 'GREEN');
  }
}

sub require_arg
{
  my $argument_num = shift;
  if (!defined($ARGV[$argument_num]))
  {
    style_text("There are not enough arguments defined!\n", 'red');
    die();
  }
}

sub main
{
  get_title();
  check_dependencies();
  check_authentication();

  # Check command and run appropriate submodule
  if ($COMMAND eq 'status')
  {
    print_all_status();
  }
  elsif ($COMMAND eq 'start')
  {
    require_arg(1);
    start_app($ARGV[1]);
  }
  elsif ($COMMAND eq 'stop')
  {
    require_arg(1);
    stop_app($ARGV[1]);
  }
  elsif ($COMMAND eq 'create')
  {
    require_arg(1);
    create_app($ARGV[1]);
  }
  elsif ($COMMAND eq 'delete')
  {
    require_arg(1);
    delete_app($ARGV[1]);
  }
  elsif ($COMMAND eq 'update')
  {
    require_arg(1);
    #update_app();
  }
  else
  {
    # By default, show basic help
    basic_help();
  }
}
