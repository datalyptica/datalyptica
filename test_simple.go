package main

import (
	"fmt"
	"html/template"
	"net/http"
	
	"github.com/gin-gonic/gin"
)

func main() {
	// Try to load templates
	templates, err := template.ParseGlob("web/templates/**/*.html")
	if err != nil {
		fmt.Printf("Template loading error: %v\n", err)
		return
	}
	fmt.Printf("Templates loaded successfully: %v\n", templates.DefinedTemplates())
	
	// Simple gin server
	r := gin.Default()
	r.LoadHTMLGlob("web/templates/**/*.html")
	r.Static("/static", "./web/static")
	
	r.GET("/", func(c *gin.Context) {
		c.HTML(http.StatusOK, "installer/index.html", gin.H{
			"Title": "Test ShuDL Installer",
			"Version": "v1.0.0-test",
			"Description": "Test installer",
		})
	})
	
	fmt.Println("Starting test server on :8088")
	r.Run(":8088")
}
