package Plagger::Plugin::Publish::Slack;
use strict;
use base qw( Plagger::Plugin );
use LWP::UserAgent;
use JSON;
use Encode;

# プラグインのバージョン
our $VERSION = '0.01';

sub register {
    my($self, $context) = @_;
    $context->register_hook(
        $self,
        'publish.entry' => \&publish,
    );
}

# config.yamlで利用可能な設定を定義する
sub MungeConfig {
    my ($self, $conf) = @_;

    # webhook_urlは必須項目
    die "Notify::Slack: 'webhook_url' is required in your config.yaml"
        unless $conf->{webhook_url};
}

sub publish {
    my($self, $context, $args) = @_;
    my $entry = $args->{entry};
    
    # Slack設定を取得
    my $webhook_url = $self->conf->{webhook_url} || '';
    my $channel = $self->conf->{channel} || '#general';
    my $username = $self->conf->{username} || 'Plagger Bot';
    my $icon_emoji = $self->conf->{icon_emoji} || ':newspaper:';
    
    return unless $webhook_url;
    
    # エントリの内容を安全に取得
    my $title = eval { $entry->title } || 'No Title';
    my $body = eval { $entry->body } || 'No Body';
    my $author = eval { $entry->author } || 'Unknown Author';
    my $date = eval { $entry->date } || 'Unknown Date';
    my $link = eval { $entry->link } || '';
    
    # authorを文字列に変換（オブジェクトの場合）
    if (ref($author)) {
        $author = "$author";
    }
    
    # dateを文字列に変換（オブジェクトの場合）
    if (ref($date)) {
        $date = "$date";
    }
    
    # タグ情報を安全に取得
    my $tags = '';
    if (ref($entry) && $entry->can('tags')) {
        my $tag_list = eval { $entry->tags };
        if ($tag_list && ref($tag_list) eq 'ARRAY') {
            $tags = join(', ', @$tag_list);
        }
    }
    
    # Slackメッセージを構築
    my $message = {
        channel => $channel,
        username => $username,
        icon_emoji => $icon_emoji,
        text => "📰 *$title*",
        attachments => [
            {
                color => "good",
                fields => [
                    {
                        title => "著者",
                        value => $author,
                        short => 1
                    },
                    {
                        title => "日付",
                        value => $date,
                        short => 1
                    }
                ],
                text => substr($body, 0, 1000) . (length($body) > 1000 ? "..." : ""),
                footer => $tags ? "タグ: $tags" : undef
            }
        ]
    };
    
    # リンクがある場合は追加
    if ($link) {
        push @{$message->{attachments}[0]{fields}}, {
            title => "リンク",
            value => $link,
            short => 0
        };
    }
    
    # Slackに投稿
    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    
    # JSONエンコードを安全に行う
    my $json_content;
    eval {
        $json_content = encode_json($message);
    };
    if ($@) {
        $context->log(error => "JSONエンコードエラー: $@");
        # フォールバック: シンプルなメッセージを送信
        $json_content = encode_json({
            channel => $channel,
            username => $username,
            icon_emoji => $icon_emoji,
            text => "📰 *$title*\n$link"
        });
    }
    
    # ここでUTF-8にエンコード
    $json_content = Encode::encode('UTF-8', $json_content);
    
    my $response = $ua->post($webhook_url, 
        Content_Type => 'application/json',
        Content => $json_content
    );
    
    if ($response->is_success) {
        $context->log(info => "Slackに投稿しました: $title");
    } else {
        $context->log(error => "Slack投稿エラー: " . $response->status_line);
    }
}

1;
