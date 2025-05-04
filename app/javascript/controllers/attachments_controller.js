import { Controller } from "@hotwired/stimulus"

// Handles file attachments for the entry form
export default class extends Controller {
  static targets = ["input"]
  
  connect() {
    // Keep track of selected files across multiple selections
    this.selectedFiles = new DataTransfer()
    
    // Initialize the input event listener
    this.inputTarget.addEventListener("change", this.handleFileSelection.bind(this))
  }
  
  disconnect() {
    // Remove event listener when controller disconnects
    this.inputTarget.removeEventListener("change", this.handleFileSelection.bind(this))
  }
  
  handleFileSelection(event) {
    // Get newly selected files
    const newFiles = Array.from(event.target.files || [])
    
    if (newFiles.length > 0) {
      // Add each new file to our collection if not already present
      newFiles.forEach(file => {
        if (!this.isDuplicate(file)) {
          this.selectedFiles.items.add(file)
        }
      })
      
      // Update the file input with combined files
      this.inputTarget.files = this.selectedFiles.files
      
      // Update the visual display of selected files
      this.updateFilesList()
    }
  }
  
  // Check if a file is already in our collection
  isDuplicate(file) {
    const existingFiles = Array.from(this.selectedFiles.files)
    return existingFiles.some(existingFile => 
      existingFile.name === file.name && 
      existingFile.size === file.size && 
      existingFile.type === file.type
    )
  }
  
  // Update the visual list of selected files
  updateFilesList() {
    const filesList = document.getElementById("selected-files-list")
    if (!filesList) return
    
    const files = Array.from(this.selectedFiles.files)
    
    if (files.length > 0) {
      let html = '<div class="mb-4 border rounded-md p-3 bg-blue-50">'
      html += '<h4 class="text-sm font-medium text-gray-700 mb-2">Selected files to upload:</h4>'
      html += '<ul class="divide-y divide-gray-200">'
      
      files.forEach(file => {
        // Format file size
        const sizeInKB = (file.size / 1024).toFixed(1)
        const fileSize = sizeInKB < 1024 ? `${sizeInKB} KB` : `${(sizeInKB / 1024).toFixed(1)} MB`
        
        html += `
          <li class="py-2 flex items-center">
            <div class="flex items-center flex-grow">
              <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 text-gray-400 mr-2 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
              </svg>
              <span class="text-sm text-gray-600 truncate">${file.name}</span>
            </div>
            <span class="ml-4 text-xs text-gray-500 flex-shrink-0">${fileSize}</span>
          </li>
        `
      })
      
      html += '</ul></div>'
      filesList.innerHTML = html
    } else {
      filesList.innerHTML = ''
    }
  }
}