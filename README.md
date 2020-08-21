**INSTALLING INSTRUCTIONS**
=======================
- Install perl
- Download Consciousnet source code:
```
git clone https://github.com/davidepatti/consciousnet
```
- Edit Data_example.pm, putting your cx and api_key obtained at:
```

https://cse.google.com/cse/manage/all
https://console.developers.google.com/apis
```
- rename Data_example.pm to Data.pm
- Install Eliza using cpan: 
```
sudo cpan install Chatbot::Eliza
```
- Now, copy the modified Eliza.pm  provided with consciousnet in order to replace the original file provided by the Eliza cpan module. For example, in macosx you could try:
```
sudo cp Eliza.pm /opt/local/lib/perl5/site_perl/PERL_VERSION/Chatbot
```
or 
```
sudo cp Eliza.pm /Library/Perl/PERL_VERSION/Chatbot 
```
or (Ubuntu Linux) 
```
sudo cp Eliza.pm /usr/local/share/perl/PERL_VERSION/Chatbot/Eliza.pm
```

Of course, change this last command according to your cpan installation directory.

Now, you are ready to go:
```
perl entity.pl
```

