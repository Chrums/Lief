using UnityEngine;
using UnityEngine.InputSystem;

namespace Fizz6.Lief
{
    public class CharacterInput : MonoBehaviour
    {
        [SerializeField] 
        private PlayerInput playerInput;
        
        [SerializeField] 
        private Animator animator;
        
        private void OnMove(InputValue value)
        {
            var direction = value.Get<Vector2>();
            if (direction.y > 0)
                animator.SetTrigger("WalkForwards");
            if (direction.y < 0)
                animator.SetTrigger("WalkBackwards");
            if (direction.x > 0)
                animator.SetTrigger("WalkRight");
            if (direction.x < 0)
                animator.SetTrigger("WalkLeft");
            if (direction.x == 0 && direction.y == 0)
                animator.SetTrigger("Idle");
            
        }
    }
}
