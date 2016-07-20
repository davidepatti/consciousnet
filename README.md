INSTALLING INSTRUCTIONS
=======================
- Install perl
- Download consciousnet source code:
- = git clone https://github.com/davidepatti/consciousnet =
- edit Data_example.pm, putting your cx and api_key
- rename it to Data.pm
- Install Eliza using cpan: 
sudo cpan install Chatbot::Eliza
- Download Chatbot::Eliza perl module source, replace the modified Eliza.pm 
  provided with consciousnet, and reinstall the module (using
  makefilem not cpan)

