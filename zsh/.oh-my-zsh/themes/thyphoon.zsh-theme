thyphoon_identity='%{$fg_bold[green]%}%n%{$reset_color%}'
if [[ -n "$SSH_CONNECTION" || -n "$SSH_TTY" ]]; then
  thyphoon_identity='%{$fg_bold[green]%}%n%{$fg_bold[blue]%}@%{$fg_bold[red]%}%m%{$reset_color%}'
fi

PROMPT="${thyphoon_identity} %{$fg[cyan]%}%~%u%{$reset_color%} \$(git_prompt_info)%{$reset_color%}%}\$returncode%{$reset_color%}\$ "

ZSH_THEME_GIT_PROMPT_PREFIX="(%{$fg_bold[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX=")"
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[green]%} %{$fg[yellow]%}✗%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$reset_color%}"
