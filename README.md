# AudioBookFetcher

Экспериментальный загрузчик аудио книг с akniga.org для дальнейшей обработки [m4b-tool](https://github.com/sandreas/m4b-tool)

```shell
swift run abookfetcher 'https://akniga.org/vnutrennie-teni' ~/Downloads/audiobooks
m4b-tool --jobs=6 merge ~/Downloads/audionbooks/Вышегородский\ Вячеслав/Внутренние\ Тени --batch-pattern="audiobooks/%a/%n/
```
