from PIL import Image
import os

def rendre_monochrome(chemin_entree, chemin_sortie):
    """
    Convertit une image en monochrome (niveaux de gris) et la sauvegarde.
    """
    try:
        # Vérifier si l'image source existe
        if not os.path.exists(chemin_entree):
            print(f"Erreur : L'image '{chemin_entree}' est introuvable.")
            return

        # 1. Ouvrir l'image originale
        image = Image.open(chemin_entree)
        
        # 2. Convertir l'image
        # Le mode 'L' convertit l'image en niveaux de gris (Luminance)
        # Si vous voulez du noir et blanc pur (sans gris), utilisez '1' à la place de 'L'
        image_monochrome = image.convert('L')
        
        # 3. Sauvegarder la nouvelle image
        image_monochrome.save(chemin_sortie)
        
        print(f"✅ Succès ! L'image a été transformée et sauvegardée sous : {chemin_sortie}")
        
    except Exception as e:
        print(f"❌ Une erreur s'est produite lors du traitement : {e}")

# ==========================================
# Zone d'exécution (à modifier selon vos besoins)
# ==========================================
if __name__ == "__main__":
    # Nom de votre image de départ (à remplacer par le vrai nom de votre photo)
    image_source = "photo.jpg" 
    
    # Nom que vous souhaitez donner à l'image transformée
    image_resultat = "photo_monochrome.jpg"
    
    # Lancement de la fonction
    rendre_monochrome(image_source, image_resultat)