#!/usr/bin/env perl
use Mojolicious::Lite;
use Data::Dumper;
use Pithub::Users;

use File::Basename 'basename';
use File::Path 'mkpath';

my $IMAGE_BASE = '/image-bbs/image';

# Directory to save image files
# (app is Mojolicious object. static is MojoX::Dispatcher::Static object)
my $IMAGE_DIR  = app->home->rel_file('/public') . $IMAGE_BASE;

# Create directory if not exists
unless (-d $IMAGE_DIR) {
  mkpath $IMAGE_DIR or die "Cannot create dirctory: $IMAGE_DIR";
}


# OAuth認証の設定
plugin "OAuth2" => {
    github => {
      key => "git_key",
      secret => "git_secret_key",
    },
};

# Documentation browser under "/perldoc"
plugin 'PODRenderer';


get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

# ログイン画面
get '/login' => sub {
  my $c = shift;
  $c->render(template => 'login');
};

# githubによるOauth認証
get '/github_auth' => sub {
	my $c = shift;
	# login してない場合
	unless (0) {
		# error 処理
		if (my $error = $c->param('error')) {
		    return $c->render(
		    	text => "Call to github returned: $error"
		    );
		    $c->redirect_to('/login');
		# 成功した場合
		} else {
		    $c->delay(
				sub {
					my $delay = shift;
					$c->oauth2->get_token(github => $delay->begin);
				},
				sub {
					# oauth 成功した時はこれが実行される
					my ($delay, $error, $data) = @_;
					return $c->render(error => $error) unless $data->{access_token};
					$c->app->log->debug(Dumper($data));
					#$c->render(template => 'admin');
					#my $u = Pithub::Users->new;
					#my $result = $u->get( user => 'Nishis');
					$c->session(key => 'in');
					$c->render(template => 'oauth');

				},
		    );
		}
	} else {
		$c->app->log->info("Login!!");
	}
};


# loginの処理
post '/auth' => sub {
	my $c = shift;
	my $user = $c->param('user');
	my $pass = $c->param('pass');
	if ($user eq 'Nishi' && $pass eq '00001111'){
		$c->session(key => 'in',name => $user);
		$c->redirect_to('/admin');

	} else {
		$c->app->log->info('login faild');
		$c->redirect_to('/login');
	}
};


# ここから下は、under(認証)の領域
under '/' => sub {
	my $c = shift;

	if($c->session('key') eq 'in') {
		return 1;
	} else {
		$c->redirect_to('login')
	}

	$c->app->log->info("!!!!!!");
};

get '/admin' => sub {
	my $c = shift;
	$c->stash->{username} = $c->session('name');
	$c->render(template => 'admin');
};

get '/main' => sub{
	my $c = shift;
	$c->render(template => 'main');
};

get '/logout' => sub {
	my $c = shift;
	$c->session(key => 'out');
	$c->redirect_to('/login');
};

# =========================================

post '/upload' => sub {
	my $c = shift;
	#my $comment = $c->param('test');

	# Upload
	my $image = $c->req->upload('image');

	#$c->app->log->info($comment);
	$c->app->log->info($image->size);

	# Not upload
	unless($image) {
		return $c->render(
			template => 'error',
			message => 'Upload fail. File is not specified.'
		);
	}

	# Upload max size
	my $upload_max_size = 3 * 1024 * 1024;

	# Over max size
	if($image->size > $upload_max_size) {
		return $c->render(
			template => 'error',
			message => 'Upload fail. Image size is too large.'
		);
	}

	# Check file type
	my $image_type = $image->headers->content_type;
	my %valid_types = map{$_ => 1} qw(image/gif image/jpeg image/png);

	# Content type is wrond
	unless ($valid_types{$image_type}) {
		return $c->render(
			template => 'error',
			message => 'Upload fail. Content type is wrong.'
		);
	}

	# Extention
	my $exts = {'image/gif' => 'gif', 'image/jpeg' => 'jpg',
	'image/png' => 'png'};
	my $ext = $exts->{$image_type};

	# Image file
	my $image_file = "$IMAGE_DIR/" . "test". ".$ext";

	# If file is exists, Retry creating filename
	while(-f $image_file){
		$image_file = "$IMAGE_DIR/" . "test" . ".$ext";
	}

	# Save to file
	$image->move_to($image_file);

	# Redirect to top page
	$c->redirect_to('main');
} => 'update';


app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>
To learn more, you can browse through the documentation
<%= link_to 'here' => '/perldoc' %>.

@@ login.html.ep
% layout 'default';
% title 'login';
<form action='/auth' method='post'>
<input type='text' name='user'><br>
<input type='password' name='pass'>
<input type='submit'><br>
<%= link_to "GitHub",'/github_auth' %>
</form>

@@ admin.html.ep
% layout 'default';
% title 'Admin';
<p> Success! </p>
<p> <%= $username %></p>
<%= link_to 'main' => '/main' %>
<%= link_to 'logout' => '/logout' %>

@@ oauth.html.ep
% layout 'default';
% title 'Oauth';
<p> Success! </p>
<%= link_to 'main' => '/main' %>
<%= link_to 'logout' => '/logout' %>


@@ main.html.ep
% layout 'default';
% title 'main';
<h1> Web Application Page </h1>

<form method='post' action="<%= url_for('upload') %>" enctype ="multipart/form-data">
<div>
<input type='file' name='image'>
<input type='submit' value='Upload'>
</div>
</form>

<%= link_to 'logout' => '/logout' %>



@@ error.html.ep
<html>
  <head>
    <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
    <title>Error</title>
  </head>
  <body>
    <%= $message %>
    <%= link_to 'back' => '/main'%>
  </body>
</html>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8" >
  <title><%= title %></title></head>
  <body><%= content %></body>
</html>
