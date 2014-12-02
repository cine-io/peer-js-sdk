
module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON("package.json")

    browserify:
      development:
        files:
          'build/compiled-dev.js': ['src/main.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify', ['envify', NODE_ENV: 'development']]

      production:
        files:
          'build/compiled-prod.js': ['src/main.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify', ['envify', NODE_ENV: 'production']]

      tests:
        files:
          'compiled/all-tests.js': ['src/main.coffee', 'test/test_helper.coffee', 'test/*.coffee']
        options:
          browserifyOptions:
            extensions: ['.coffee', '.js']
          transform: ['coffeeify']

    uglify:
      production:
        files:
          'build/compiled-prod.js': ['build/compiled-prod.js']

    watch:
      grunt:
        files: ["Gruntfile.coffee"]

      main:
        files: ["src/*.coffee"]
        tasks: ["compile"]

      tests:
        files: ["test/*.coffee", "test/**/*.coffee", "src/*.coffee", "src/**/*.js"]
        tasks: ["browserify:tests"]

    trimtrailingspaces:
      development:
        src: ['build/compiled-dev.js']

    mocha:
      all:
        src: ['test/runner.html']
      options:
        run: true
        log: true
        reporter: 'Spec'

  grunt.loadNpmTasks('grunt-browserify')
  grunt.loadNpmTasks('grunt-contrib-coffee')
  grunt.loadNpmTasks('grunt-mocha')
  grunt.loadNpmTasks("grunt-contrib-watch")
  grunt.loadNpmTasks('grunt-contrib-uglify')
  grunt.loadNpmTasks('grunt-trimtrailingspaces')

  grunt.registerTask "compile:production", ["browserify:production", "uglify"]
  grunt.registerTask "compile:development", ["browserify:development", "trimtrailingspaces:development"]
  grunt.registerTask "compile", ["compile:development", "compile:production"]

  grunt.registerTask "test", ["browserify:tests", "mocha"]

  grunt.registerTask "default", ["compile", "browserify:tests", "watch"]
