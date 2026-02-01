# Dotfiles
```
 git        > global git configuration
 ghostty    > ghostty terminal settings
 zsh        > oh-my-zsh plugins and themes
 ```

# Dependencies
* zsh & [oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh)
* https://github.com/VundleVim/Vundle.vim
* [Antibody](https://getantibody.github.io/usage/)
* [Hack Nerd Font](https://www.nerdfonts.com/font-downloads)
## MacOS
* [Homebrew](https://brew.sh/)
* [Jabba](https://github.com/shyiko/jabba)
```
brew install stow getantibody/tap/antibody groovysdk htop gpg2 gnupg pinentry-mac kryptco/tap/kr 
```

## WSL/Debian
```
sudo apt install stow zsh-antidote
sudo ln -s /usr/share/zsh-antidote/antidote.zsh /usr/bin/antidote.zsh
```

# Usage
I use [stow](https://www.gnu.org/software/stow/) to manage my dotfiles
```
git clone git@github.com:ThYpHo0n/dotfiles.git ~/dotfiles
cd ~/dotfiles
stow ghostty zsh git
```

## Per-machine git setup
The shared git config (`git/.gitconfig`) pulls in a local override via `[include]`.
Copy the example and fill in your identity:
```
cp ~/dotfiles/git/.gitconfig.local.example ~/.gitconfig.local
# edit ~/.gitconfig.local with your name, email, and any signing keys
```

Inspired & based on by [aeolyus/dotfiles](https://github.com/aeolyus/dotfiles)
