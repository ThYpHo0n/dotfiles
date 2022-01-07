# Dotfiles
```
 git        > global git configuration
 hyper.is   > hyper.is terminal settings
 zsh        > oh-my-zsh plugins and themes
 ```

# Dependencies
* zsh & [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)
* https://github.com/VundleVim/Vundle.vim
* [WakaTime](https://wakatime.com)
* [Antibody](https://getantibody.github.io/usage/)
## MacOS
* [Homebrew](https://brew.sh/)
* [Jabba](https://github.com/shyiko/jabba)
```
brew install stow getantibody/tap/antibody groovysdk htop gpg2 gnupg pinentry-mac kryptco/tap/kr 
```
# Usage
I use [stow](https://www.gnu.org/software/stow/) to manage my dotfiles
```
git clone https://github.com/aeolyus/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow zsh
```

Inspired & based on by [aeolyus/dotfiles](https://github.com/aeolyus/dotfiles)
