#!/usr/bin/perl

# This is the source for webpush client application
# This can be compiled using pp

use strict;
use warnings;
use Text::FormatTable;
use Term::ANSIColor;
use Term::ReadKey;
use Data::Dumper;


my $SERVER = 'localhost';
my $REMOTE_USER = 'root';
my $TEMPLATE_FILE = '/root/apachetemplate';
my $TEMPLATE_TEMP_VALUE = 'WEBPUSH_APP_NAME';
my $SITES_AVAILABLE_DIR = '/etc/apache2/sites-available';
my $SITES_ENABLED_DIR = '/etc/apache2/sites-enabled';
my $APP_BASE_DIR = '/var/www';
my $COMMAND = '';
if (defined($ARGV[0]))
{
  $COMMAND = lc($ARGV[0]);
}

main();

sub check_dependencies
{
  # This will need to check depencies for this app
  # The following packages must be installed:
    # libtext-formattable-perl
    # libterm-readkey-perl

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

sub get_credentials
{
  # Get username
  print "Username: ";
  my $username = ReadLine(0);
  chomp($username);

  # Get password
  print "Password: ";
  ReadMode('noecho');
  my $password = ReadLine(0);
  chomp($password);
  ReadMode('normal');
  print "\n";

  # Return hash with credentials
  my %return_hash;
  $return_hash{'username'} = $username;
  $return_hash{'password'} = $password;
  return %return_hash;
}

sub run_command
{
  my $command = shift;
  my $command_output = `ssh -o 'PasswordAuthentication=no' -o 'StrictHostKeyChecking=no' $REMOTE_USER\@$SERVER "$command"`;
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
    my $app_dir = get_app_dir($app_name);
    my %git_output = run_command("ls $app_dir/.git");
    my %svn_output = run_command("ls $app_dir/.svn");
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

sub get_app_config
{
  my $app_name = shift;
  return "$SITES_AVAILABLE_DIR/$app_name";
}

sub create_app
{
  my $app_name = shift;
  my $config_file = get_app_config($app_name);
  my $app_dir = get_app_dir($app_name);
  if (check_app_exists($app_name))
  {
    style_text("ERROR: App already exists\n", 'RED');
  }
  else
  {
    my %create_config = run_command("cp $TEMPLATE_FILE $config_file");
    run_command("sed -i 's/$TEMPLATE_TEMP_VALUE/$app_name/g' $config_file");
    my %create_dir = run_command("mkdir $app_dir");
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
    my $config_file = get_app_config($app_name);
    my $app_dir = get_app_dir($app_name);
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

sub get_app_dir
{
  my $app_name = shift;
  return "$APP_BASE_DIR/$app_name";
}

sub update_app
{
  my ($app_name, $revision) = @_;
  my $app_dir = get_app_dir($app_name);
  my $git_dir = "$app_dir/.git";
  if (check_app_exists($app_name))
  {
    my $repo_type = get_app_repo_type($app_name);
    if ($repo_type == 0)
    {
      # I need to upload the client's files :S
    }
    # If the repo type is git
    elsif ($repo_type == 1)
    {
      my %update_output = run_command("git --work-tree=$app_dir --git-dir=$git_dir checkout $revision");
      if ($update_output{'exit_code'})
      {
        style_text("ERROR: A problem occurred during git checkout:\n", 'RED');
        die($update_output{'output'});
      }
      else
      {
        style_text("SUCCESS: $app_name has been updated to $revision\n", 'GREEN');
      }
    }
    # If the repo type is SVN
    elsif ($repo_type == 2)
    {
      my %credentials = get_credentials();
      my %update_output = run_command
      (
        "svn update $app_dir -r $revision" .
        ' --username=' . $credentials{'username'} .
        ' --password=' . $credentials{'password'}
      );
      if ($update_output{'exit_code'})
      {
        style_text("ERROR: A problem occurred during svn update:\n");
        die($update_output{'output'});
      }
      else
      {
        style_text("SUCCESS: $app_name has been updated to $revision\n", 'GREEN');
      }
    }
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

sub upload_content_git
{
  my ($app_name, $content_path) = @_;
  my $app_dir = get_app_dir($app_name);
  $content_path  =~ s/@/\\@/g;
  my %upload_output = run_command("git clone $content_path $app_dir");
  return $upload_output{'exit_code'};
}

sub upload_content_svn
{
  my ($app_name, $content_path) = @_;
  my %credentials = get_credentials();
  my $app_dir = get_app_dir($app_name);
  my %upload_output = run_command
  (
    "svn checkout $content_path $app_dir" .
    ' --username=' . $credentials{'username'} .
    ' --password=' . $credentials{'password'}
  );
  return $upload_output{'exit_code'};
}

sub upload_content_local
{
  print "I am uploading local content\n";
}

sub clean_app_dir
{
  my $app_name = shift;
  if (check_app_exists($app_name))
  {
    # Clean app dir
    my $app_dir = get_app_dir($app_name);
    run_command("rm -rf $app_dir");
    run_command("mkdir $app_dir");
  }
}

sub upload_content
{
  my ($app_name, $content_path, $repo_type) = @_;

  clean_app_dir($app_name);
  if (check_app_exists($app_name))
  {
    if (lc($repo_type) eq 'git')
    {
      upload_content_git($app_name, $content_path);
    }
    elsif (lc($repo_type) eq 'svn')
    {
      upload_content_svn($app_name, $content_path);
    }
    elsif (lc($repo_type) eq 'file')
    {
      upload_content_local($app_name, $content_path);
    }
    elsif ($content_path =~ /.*@.*/)
    {
      my $git_output = upload_content_git($app_name, $content_path);
      if (!$git_output)
      {
        style_text("SUCCESS: Checked out git repo\n", 'GREEN');
      }
    }
    elsif ($content_path =~ /http.*/)
    {
      my $svn_output = upload_content_svn($app_name, $content_path);
      if ($svn_output)
      {
        my $git_output = upload_content_git($app_name, $content_path);
        if ($git_output)
        {
          upload_content_local($app_name, $content_path);
        }
        else
        {
          style_text("SUCCESS: Checked out git repo\n", 'GREEN');
        }
      }
      else
      {
        style_text("SUCCESS: Checked out SVN repo\n", 'GREEN');
      }
    }
  }
}

sub print_public_key
{
  my %public_key_output = run_command("cat ~/.ssh/id_rsa.pub");
  if ($public_key_output{'exit_code'})
  {
    style_text("ERROR: A problem occurred whilst obtaining the public key\n");
  }
  else
  {
    print "The public key for the server is:\n";
    print $public_key_output{'output'};
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
    require_arg(2);
    update_app($ARGV[1], $ARGV[2]);
  }
  elsif ($COMMAND eq 'upload')
  {
    require_arg(2);
    if (!defined($ARGV[3]))
    {
      $ARGV[3] = '';
    }
    upload_content($ARGV[1], $ARGV[2], $ARGV[3]);
  }
  elsif ($COMMAND eq 'key')
  {
    print_public_key();
  }
  else
  {
    # By default, show basic help
    basic_help();
  }
}
