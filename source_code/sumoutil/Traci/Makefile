DOCSOURCES = TraciClient.rb TraciCommand.rb \
	      TraciConstants.rb TraciDataType.rb \
	      TraciUtil.rb \
	      convTraciConstants

top : doc
build : doc TraciConstants.rb 

TraciConstants.rb ::
	./convTraciConstants -o $@

clean::
	if [ -e doc ] ; then git rm -rf --ignore-unmatch doc ; fi
	rm -rf doc

doc:: clean
	rdoc --force-update $(DOCSOURCES)
	git add doc


