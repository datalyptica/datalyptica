package main

import (
	"html/template"
	"github.com/gin-gonic/gin"
)

func main() {
	r := gin.Default()
	
	// Try explicit template loading
	tmpl := template.Must(template.ParseFiles("web/templates/installer/index.html"))
	r.SetHTMLTemplate(tmpl)
	
	r.GET("/", func(c *gin.Context) {
		c.HTML(200, "index.html", gin.H{
			"Title": "Test ShuDL Installer",
			"Version": "v1.0.0",
			"Description": "Test installer",
		})
	})
	
	r.Run(":8094")
}
