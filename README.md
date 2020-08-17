# AudioBookFetcher

Экспериментальный загрузчик аудио книг с akniga.org для дальнейшей обработки [m4b-tool](https://github.com/sandreas/m4b-tool)

```shell
swift run abookfetcher 'https://akniga.org/vnutrennie-teni' ~/Downloads/audiobooks
cd ~/Downloads
m4b-tool merge audiobooks/Вышегородский\ Вячеслав/Внутренние\ Тени --batch-pattern="audiobooks/%a/%n" --output-file=book.m4b --jobs=6
```

# Brew
```
brew tap vovast/tap
brew install audiobookfetcher
```
