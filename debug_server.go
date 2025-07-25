package main

import (
	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	
	r.GET("/", func(c *gin.Context) {
		html := `<!DOCTYPE html>
<html><head><title>ShuDL Test</title></head>
<body><h1>ShuDL Installer Test</h1><p>If you see this, the server is working!</p></body>
</html>`
		c.Header("Content-Type", "text/html; charset=utf-8")
		c.String(200, html)
	})
	
	r.Run(":8098")
}
